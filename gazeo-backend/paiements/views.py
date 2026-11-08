import json
import logging
from decimal import Decimal
from datetime import timedelta
from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Paiement, MethodePaiement, StatutPaiement, VirementHebdomadaire, StatutVirement
from .serializers import (
    InitierPaiementSerializer,
    RembourserPaiementSerializer,
    PaiementDetailSerializer,
    VirementHebdomadaireSerializer,
)
from .services.notchpay_service import NotchpayService
from auth_user.services.sms_service import TwilioSMSService
from commandes.models import Commande, StatutCommande
from depots.models import Depot

logger = logging.getLogger(__name__)
notchpay_service = NotchpayService()
sms_service = TwilioSMSService()


class InitierPaiementView(APIView):
    """
    POST /paiements/initier/
    Initie une transaction Notchpay pour régler une commande en attente :
    - Retourne l'URL de paiement vers la passerelle sécurisée Mobile Money (MTN / Orange)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = InitierPaiementSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        commande_id = serializer.validated_data['commande_id']
        telephone = serializer.validated_data.get('telephone') or request.user.telephone

        try:
            commande = Commande.objects.get(pk=commande_id)
        except Commande.DoesNotExist:
            return Response({"detail": "Commande introuvable."}, status=status.HTTP_404_NOT_FOUND)

        if commande.client != request.user and not request.user.is_staff:
            return Response(
                {"detail": "Vous n'êtes pas autorisé à régler cette commande."},
                status=status.HTTP_403_FORBIDDEN
            )

        if commande.statut in (StatutCommande.LIVREE, StatutCommande.ANNULEE):
            return Response(
                {"detail": f"Impossible de payer une commande avec statut '{commande.get_statut_display()}'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        montant_a_payer = int(commande.montant_total_client) if commande.montant_total_client else int(commande.montant_total)

        # Appel au service Notchpay pour collecter montant_total_client
        result = notchpay_service.initier_paiement(
            commande_id=commande.id,
            telephone=telephone,
            montant=montant_a_payer,
            description=f"Règlement GAZEO Commande #{commande.id}"
        )

        # Enregistrement ou mise à jour du Paiement
        paiement, _ = Paiement.objects.get_or_create(
            commande=commande,
            defaults={
                'reference_notchpay': result['reference'],
                'montant': montant_a_payer,
                'statut': StatutPaiement.PENDING,
            }
        )
        paiement.montant = montant_a_payer
        paiement.reference_notchpay = result['reference']
        paiement.save()

        return Response({
            "message": "Paiement initialisé",
            "authorization_url": result['authorization_url'],
            "reference": result['reference'],
            "montant": int(montant_a_payer),
            "montant_total_client": int(montant_a_payer),
            "paiement_id": paiement.id,
        }, status=status.HTTP_200_OK)


class NotchpayWebhookView(APIView):
    """
    POST /paiements/webhook/notchpay/
    Endpoint public appelé par les serveurs de Notchpay :
    1. Vérification de la signature cryptographique HMAC-SHA256
    2. Contrôle d'idempotence (si déjà traité, ignorer)
    3. Si succès -> statut=SUCCESS + calcul commission 1.5% + notification
    4. Si échec -> statut=FAILED + annulation et restitution de stock
    """
    permission_classes = [AllowAny]

    def post(self, request):
        signature = (
            request.headers.get('x-notch-signature') or
            request.headers.get('X-Notch-Signature') or
            request.META.get('HTTP_X_NOTCH_SIGNATURE', '')
        )

        # 1. Vérification HMAC
        notchpay_service.verifier_webhook(request.body, signature)

        try:
            payload = json.loads(request.body.decode('utf-8'))
        except (ValueError, UnicodeDecodeError):
            return Response({"detail": "Payload JSON invalide."}, status=status.HTTP_400_BAD_REQUEST)

        # Extraction des informations selon les formats d'événements Notchpay
        event_data = payload.get('data', payload)
        reference = event_data.get('reference')
        event_status = (event_data.get('status') or payload.get('event') or '').lower()

        if not reference:
            return Response({"detail": "Référence manquante dans le webhook."}, status=status.HTTP_400_BAD_REQUEST)

        paiement = Paiement.objects.filter(reference_notchpay=reference).select_related('commande', 'commande__depot').first()
        if not paiement:
            logger.warning(f"[Notchpay Webhook] Paiement introuvable pour la référence {reference}")
            return Response({"detail": "Paiement introuvable."}, status=status.HTTP_404_NOT_FOUND)

        # 2. Idempotence : si déjà validé, ne pas retraiter
        if paiement.statut == StatutPaiement.SUCCESS:
            logger.info(f"[Notchpay Webhook] Événement déjà traité pour {reference} (Idempotence respectée).")
            return Response({"status": "already_processed"}, status=status.HTTP_200_OK)

        # 3. Traitement selon statut Notchpay
        if any(s in event_status for s in ('complete', 'successful', 'success', 'paid')):
            with transaction.atomic():
                paiement.statut = StatutPaiement.SUCCESS
                paiement.calculer_commissions()
                paiement.raw_response = payload
                paiement.save()

                logger.info(
                    f"[Notchpay Webhook] Paiement {reference} CONFIRMÉ : "
                    f"{paiement.montant} FCFA (Commission GAZEO: {paiement.commission_gazeo} FCFA, "
                    f"Net Gérant: {paiement.montant_net_gerant} FCFA)"
                )

                # SMS de confirmation au client
                sms_service.send_sms(
                    paiement.commande.client.telephone,
                    f"Votre paiement GAZEO de {paiement.montant} FCFA pour la commande #{paiement.commande.id} a été validé avec succès !"
                )

                # Notification push FCM au gérant
                try:
                    from notifications.services.fcm_service import FCMService
                    FCMService.notifier_paiement_recu(paiement)
                except Exception as fcm_err:
                    logger.warning(f"Erreur FCM paiement reçu: {fcm_err}")

                # Réinitialiser le compteur d'échecs consécutifs
                try:
                    from django.core.cache import cache
                    cache.delete('notchpay_echecs_consecutifs')
                except Exception:
                    pass


        elif any(s in event_status for s in ('failed', 'expired', 'canceled')):
            with transaction.atomic():
                paiement.statut = StatutPaiement.FAILED
                paiement.raw_response = payload
                paiement.save()

                # Restitution du stock si la commande était encore en attente
                commande = paiement.commande
                if commande.statut == StatutCommande.EN_ATTENTE:
                    depot = Depot.objects.select_for_update().get(id=commande.depot_id)
                    depot.stock_6kg += commande.quantite_6kg
                    depot.stock_12kg += commande.quantite_12kg
                    depot.save(update_fields=['stock_6kg', 'stock_12kg', 'updated_at'])

                    commande.statut = StatutCommande.ANNULEE
                    commande.save(update_fields=['statut', 'updated_at'])

                logger.warning(f"[Notchpay Webhook] Paiement {reference} ÉCHOUÉ ({event_status}). Commande annulée.")

                # Suivi des échecs consécutifs et alerte admin si > 3 (Prompt 7.2)
                try:
                    from django.core.cache import cache
                    from .tasks import alerter_echec_paiement_repete_task
                    echecs = cache.get('notchpay_echecs_consecutifs', 0) + 1
                    cache.set('notchpay_echecs_consecutifs', echecs, timeout=3600)
                    if echecs > 3:
                        alerter_echec_paiement_repete_task.delay(echecs)
                except Exception as alert_err:
                    logger.warning(f"Erreur déclenchement alerte échec paiement répété: {alert_err}")

        return Response({"status": "received", "statut_paiement": paiement.statut}, status=status.HTTP_200_OK)



class RembourserPaiementView(APIView):
    """
    POST /paiements/{id}/rembourser/
    Action réservée aux administrateurs (Prompt 5.2) :
    - Déclenche le remboursement Notchpay
    - Notifie le client par SMS
    - Met à jour la traçabilité comptable
    """
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            paiement = Paiement.objects.select_related('commande', 'commande__client').get(pk=pk)
        except Paiement.DoesNotExist:
            return Response({"detail": "Paiement introuvable."}, status=status.HTTP_404_NOT_FOUND)

        if paiement.statut != StatutPaiement.SUCCESS:
            return Response(
                {"detail": f"Seul un paiement confirmé (SUCCESS) peut être remboursé. Statut actuel: {paiement.statut}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = RembourserPaiementSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        motif = serializer.validated_data.get('motif', 'Annulation de commande')

        # Appel à Notchpay refund
        res = notchpay_service.rembourser_paiement(
            reference_notchpay=paiement.reference_notchpay,
            montant=paiement.montant,
            motif=motif
        )

        with transaction.atomic():
            paiement.statut = StatutPaiement.REFUNDED
            paiement.rembourse_at = timezone.now()
            paiement.rembourse_par = request.user
            paiement.motif_remboursement = motif
            paiement.save()

            # SMS au client
            sms_service.send_sms(
                paiement.commande.client.telephone,
                f"Votre remboursement GAZEO de {paiement.montant} FCFA a été effectué sur votre compte Mobile Money."
            )

        return Response({
            "message": "Paiement remboursé avec succès",
            "paiement": PaiementDetailSerializer(paiement).data,
            "reponse_notchpay": res,
        }, status=status.HTTP_200_OK)


class CalculerVirementsHebdomadairesView(APIView):
    """
    GET /paiements/virements-gerants/calcul/
    Calcule pour chaque gérant les revenus hebdomadaires :
    Revenus = Total livré - Commission 1,5% GAZEO (Prompt 5.2)
    Réservé aux administrateurs.
    """
    permission_classes = [IsAdminUser]

    def get(self, request):
        fin = timezone.now().date()
        debut = fin - timedelta(days=7)

        # Récupère tous les dépôts actifs avec des commandes livrées sur la période
        depots = Depot.objects.select_related('gerant').all()
        resultats = []

        for depot in depots:
            commandes_livrees = Commande.objects.filter(
                depot=depot,
                statut=StatutCommande.LIVREE,
                created_at__date__gte=debut,
                created_at__date__lte=fin
            )
            total_brut = sum(c.montant_total for c in commandes_livrees)
            if total_brut > 0:
                commission = round(total_brut * Decimal('0.015'), 2)
                net = round(total_brut - commission, 2)

                virement, _ = VirementHebdomadaire.objects.get_or_create(
                    gerant=depot.gerant,
                    periode_debut=debut,
                    periode_fin=fin,
                    defaults={
                        'total_brut': total_brut,
                        'commission_gazeo': commission,
                        'net_a_verser': net,
                        'statut': StatutVirement.EN_ATTENTE,
                    }
                )
                resultats.append(virement)

        serializer = VirementHebdomadaireSerializer(resultats, many=True)
        return Response({
            "periode": {
                "debut": debut,
                "fin": fin,
            },
            "taux_commission": "1.5%",
            "nombre_gerants": len(resultats),
            "virements": serializer.data
        }, status=status.HTTP_200_OK)
