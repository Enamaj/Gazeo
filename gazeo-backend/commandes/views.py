import logging
import math
import random
from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Commande, SuiviPosition, StatutCommande
from .serializers import (
    CreerCommandeSerializer,
    ConfirmerLivraisonSerializer,
    AccepterCommandeSerializer,
    SuiviPositionInputSerializer,
    SuiviPositionSerializer,
    CommandeDetailSerializer,
)
from auth_user.models import User, UserRole
from depots.models import Depot
from depots.permissions import IsGerant
from fidelite.models import Transaction as FideliteTransaction, TypeTransaction

logger = logging.getLogger(__name__)


def generate_delivery_code() -> str:
    """Génère un code OTP de confirmation de livraison à 6 chiffres."""
    return f"{random.randint(100000, 999999)}"


def calculate_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calcul de distance approximative en km (Haversine)."""
    rad = math.pi / 180.0
    dlat = (lat2 - lat1) * rad
    dlon = (lon2 - lon1) * rad
    a = (math.sin(dlat / 2) ** 2) + math.cos(lat1 * rad) * math.cos(lat2 * rad) * (math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return 6371.0 * c


class CreerCommandeView(APIView):
    """
    POST /commandes/creer/
    Création de commande sécurisée par transaction atomique :
    1. SELECT FOR UPDATE sur le dépôt
    2. Vérification des stocks
    3. Déduction immédiate du stock
    4. Création de la commande avec statut EN_ATTENTE
    5. Code OTP de livraison généré
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CreerCommandeSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        depot_id = data['depot_id']
        qte_6 = data['quantite_6kg']
        qte_12 = data['quantite_12kg']

        try:
            with transaction.atomic():
                # 1. Verrou pessimiste SELECT FOR UPDATE
                depot = Depot.objects.select_for_update().get(id=depot_id)

                if not depot.est_actif:
                    return Response(
                        {"detail": "Ce dépôt n'est actuellement pas disponible pour recevoir des commandes."},
                        status=status.HTTP_400_BAD_REQUEST
                    )

                # 2. Vérification de la disponibilité du stock
                if depot.stock_6kg < qte_6:
                    return Response(
                        {"detail": f"Stock insuffisant pour bouteilles 6kg (disponible: {depot.stock_6kg}, demandé: {qte_6})."},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                if depot.stock_12kg < qte_12:
                    return Response(
                        {"detail": f"Stock insuffisant pour bouteilles 12.5kg (disponible: {depot.stock_12kg}, demandé: {qte_12})."},
                        status=status.HTTP_400_BAD_REQUEST
                    )

                # 3. Calculs financiers
                montant_gaz = (qte_6 * depot.prix_6kg) + (qte_12 * depot.prix_12kg)
                frais_livraison = Decimal('1000.00')
                montant_total = montant_gaz + frais_livraison

                # 4. Déduction atomique du stock
                depot.stock_6kg -= qte_6
                depot.stock_12kg -= qte_12
                depot.save(update_fields=['stock_6kg', 'stock_12kg', 'updated_at'])

                # 5. Création de la commande
                code_otp = generate_delivery_code()
                commande = Commande.objects.create(
                    client=request.user,
                    depot=depot,
                    quantite_6kg=qte_6,
                    quantite_12kg=qte_12,
                    montant_total=montant_total,
                    frais_livraison=frais_livraison,
                    statut=StatutCommande.EN_ATTENTE,
                    adresse_livraison=data['adresse_livraison'],
                    latitude_livraison=data['latitude_livraison'],
                    longitude_livraison=data['longitude_livraison'],
                    code_confirmation=code_otp,
                )

                logger.info(
                    f"[GAZEO Commande] Créée #{commande.id} par {request.user.telephone} "
                    f"au dépôt {depot.nom} - Total: {montant_total} FCFA"
                )

                return Response({
                    "message": "Commande créée avec succès",
                    "commande_id": commande.id,
                    "montant_total": float(montant_total),
                    "frais_livraison": float(frais_livraison),
                    "code_confirmation": commande.code_confirmation,
                    "statut": commande.statut,
                    "commande": CommandeDetailSerializer(commande).data,
                }, status=status.HTTP_201_CREATED)

        except Depot.DoesNotExist:
            return Response({"detail": "Dépôt spécifié introuvable."}, status=status.HTTP_404_NOT_FOUND)


class AccepterCommandeView(APIView):
    """
    PUT /commandes/{id}/accepter/
    Action du gérant : accepte la commande et assigne éventuellement un livreur.
    """
    permission_classes = [IsAuthenticated, IsGerant]

    def put(self, request, pk):
        try:
            commande = Commande.objects.get(pk=pk, depot__gerant=request.user)
        except Commande.DoesNotExist:
            return Response(
                {"detail": "Commande introuvable ou non associée à votre dépôt."},
                status=status.HTTP_404_NOT_FOUND
            )

        if commande.statut != StatutCommande.EN_ATTENTE:
            return Response(
                {"detail": f"Impossible d'accepter une commande avec statut '{commande.get_statut_display()}'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = AccepterCommandeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        livreur_id = serializer.validated_data.get('livreur_id')

        if livreur_id:
            livreur = User.objects.filter(pk=livreur_id, role=UserRole.LIVREUR).first()
            if livreur:
                commande.livreur = livreur
                commande.statut = StatutCommande.EN_LIVRAISON
            else:
                commande.statut = StatutCommande.ACCEPTEE
        else:
            commande.statut = StatutCommande.ACCEPTEE

        commande.save()

        return Response({
            "message": "Commande acceptée avec succès",
            "statut": commande.statut,
            "commande": CommandeDetailSerializer(commande).data
        }, status=status.HTTP_200_OK)


class ConfirmerCommandeView(APIView):
    """
    PUT /commandes/{id}/confirmer/
    Validation finale de livraison par le livreur via le code OTP du client :
    1. Vérification concordance OTP
    2. Statut -> LIVREE
    3. Attribution des points fidélité au client (+10 pts)
    """
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        try:
            commande = Commande.objects.get(pk=pk)
        except Commande.DoesNotExist:
            return Response({"detail": "Commande introuvable."}, status=status.HTTP_404_NOT_FOUND)

        serializer = ConfirmerLivraisonSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        code_saisi = serializer.validated_data['code_otp']

        if commande.code_confirmation != code_saisi:
            return Response(
                {"detail": "Code OTP de confirmation incorrect."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if commande.statut == StatutCommande.LIVREE:
            return Response({"detail": "Cette commande est déjà validée comme livrée."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            commande.statut = StatutCommande.LIVREE
            commande.save(update_fields=['statut', 'updated_at'])

            # Attribution de 10 points fidélité au client
            client = commande.client
            client.points_fidelite += 10
            client.save(update_fields=['points_fidelite'])

            FideliteTransaction.objects.create(
                user=client,
                commande=commande,
                points=10,
                type=TypeTransaction.GAIN
            )

        return Response({
            "message": "Livraison confirmée avec succès. Points de fidélité crédités.",
            "statut": commande.statut,
            "points_gagnes": 10,
            "nouveau_solde_points": client.points_fidelite,
            "commande": CommandeDetailSerializer(commande).data
        }, status=status.HTTP_200_OK)


class AnnulerCommandeView(APIView):
    """
    PUT /commandes/{id}/annuler/
    Annulation par le client ou le gérant :
    - Réintégration atomique des stocks dans le dépôt
    - Statut -> ANNULEE
    """
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        try:
            commande = Commande.objects.get(pk=pk)
        except Commande.DoesNotExist:
            return Response({"detail": "Commande introuvable."}, status=status.HTTP_404_NOT_FOUND)

        # Seul le client auteur, le gérant du dépôt ou un admin peut annuler
        user = request.user
        est_autorise = (
            commande.client == user or
            commande.depot.gerant == user or
            user.is_staff
        )
        if not est_autorise:
            return Response(
                {"detail": "Vous n'êtes pas autorisé à annuler cette commande."},
                status=status.HTTP_403_FORBIDDEN
            )

        if commande.statut in (StatutCommande.LIVREE, StatutCommande.ANNULEE):
            return Response(
                {"detail": f"Impossible d'annuler une commande déjà '{commande.get_statut_display()}'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        with transaction.atomic():
            depot = Depot.objects.select_for_update().get(id=commande.depot_id)
            # Réintégration du stock
            depot.stock_6kg += commande.quantite_6kg
            depot.stock_12kg += commande.quantite_12kg
            depot.save(update_fields=['stock_6kg', 'stock_12kg', 'updated_at'])

            commande.statut = StatutCommande.ANNULEE
            commande.save(update_fields=['statut', 'updated_at'])

            logger.info(f"[GAZEO Commande] Commande #{commande.id} annulée. Stocks restitués au dépôt {depot.nom}.")

        return Response({
            "message": "Commande annulée avec succès. Le stock a été restitué.",
            "statut": commande.statut,
            "commande": CommandeDetailSerializer(commande).data
        }, status=status.HTTP_200_OK)


class MesCommandesView(APIView):
    """
    GET /commandes/mes-commandes/
    Historique chronologique des commandes passées par l'utilisateur connecté.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        commandes = Commande.objects.filter(client=request.user).order_by('-created_at')
        serializer = CommandeDetailSerializer(commandes, many=True)
        return Response({
            "count": commandes.count(),
            "commandes": serializer.data
        }, status=status.HTTP_200_OK)


class MettreAJourPositionLivreurView(APIView):
    """
    POST /livraisons/{commande_id}/position/
    Enregistrement par le livreur de sa position GPS temps réel.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, commande_id):
        try:
            commande = Commande.objects.get(pk=commande_id)
        except Commande.DoesNotExist:
            return Response({"detail": "Commande introuvable."}, status=status.HTTP_404_NOT_FOUND)

        serializer = SuiviPositionInputSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        lat = serializer.validated_data['latitude']
        lon = serializer.validated_data['longitude']

        position = SuiviPosition.objects.create(
            commande=commande,
            livreur=request.user,
            latitude=lat,
            longitude=lon
        )

        return Response({
            "message": "Position GPS enregistrée",
            "position": SuiviPositionSerializer(position).data
        }, status=status.HTTP_201_CREATED)


class PositionActuelleLivreurView(APIView):
    """
    GET /livraisons/{id}/position-actuelle/
    Retourne la dernière position du livreur et l'ETA calculé (temps estimé d'arrivée).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            commande = Commande.objects.get(pk=pk)
        except Commande.DoesNotExist:
            return Response({"detail": "Commande introuvable."}, status=status.HTTP_404_NOT_FOUND)

        derniere = commande.positions.first()
        if not derniere:
            return Response({
                "statut": "NON_DISPONIBLE",
                "detail": "Aucune position GPS n'a encore été émise pour cette livraison.",
                "destination": {
                    "latitude": commande.latitude_livraison,
                    "longitude": commande.longitude_livraison,
                    "adresse": commande.adresse_livraison
                }
            }, status=status.HTTP_200_OK)

        # Calcul distance livreur -> destination
        dist_km = calculate_distance_km(
            derniere.latitude,
            derniere.longitude,
            commande.latitude_livraison,
            commande.longitude_livraison
        )

        # Estimation vitesse moyenne moto à Yaoundé : ~20 km/h
        minutes_estimees = max(2, int((dist_km / 20.0) * 60))

        return Response({
            "commande_id": commande.id,
            "statut_commande": commande.statut,
            "position_livreur": {
                "latitude": derniere.latitude,
                "longitude": derniere.longitude,
                "timestamp": derniere.timestamp,
            },
            "destination": {
                "latitude": commande.latitude_livraison,
                "longitude": commande.longitude_livraison,
                "adresse": commande.adresse_livraison,
            },
            "distance_restante_km": round(dist_km, 2),
            "eta_minutes": minutes_estimees,
        }, status=status.HTTP_200_OK)
