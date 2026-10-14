import logging
from datetime import timedelta
from decimal import Decimal
from celery import shared_task
from django.conf import settings
from django.utils import timezone

from auth_user.services.sms_service import TwilioSMSService
from depots.models import Depot
from paiements.models import Paiement, StatutPaiement, VirementHebdomadaire

logger = logging.getLogger(__name__)


@shared_task(name="paiements.calculer_virements_hebdomadaires")
def calculer_virements_hebdomadaires_task():
    """
    Tâche récurrente Celery (chaque lundi matin) pour générer les virements des gérants.
    """
    maintenant = timezone.now()
    fin_periode = maintenant
    debut_periode = maintenant - timedelta(days=7)

    depots = Depot.objects.filter(est_actif=True, gerant__isnull=False)
    virements_crees = 0

    for depot in depots:
        paiements = Paiement.objects.filter(
            commande__depot=depot,
            statut=StatutPaiement.SUCCESS,
            created_at__gte=debut_periode,
            created_at__lt=fin_periode
        )

        total_brut = sum((p.montant for p in paiements), Decimal('0.00'))
        if total_brut <= 0:
            continue

        commission_gazeo = sum((p.commission_gazeo for p in paiements), Decimal('0.00'))
        net_a_verser = sum((p.montant_net_gerant for p in paiements), Decimal('0.00'))

        virement = VirementHebdomadaire.objects.create(
            gerant=depot.gerant,
            total_brut=total_brut,
            commission_gazeo=commission_gazeo,
            net_a_verser=net_a_verser,
            periode_debut=debut_periode.date(),
            periode_fin=fin_periode.date(),
            statut='EN_ATTENTE'
        )
        virements_crees += 1
        logger.info(
            f"[Celery Payout] Virement calculé #{virement.id} pour {depot.nom} "
            f"({depot.gerant.telephone}) : Net {net_a_verser} FCFA"
        )

    return virements_crees


@shared_task(name="paiements.alerter_echec_paiement_repete")
def alerter_echec_paiement_repete_task(nb_echecs: int):
    """
    Alerte critique par SMS envoyée à l'administrateur si plus de 3 échecs consécutifs Notchpay surviennent.
    """
    admin_phone = getattr(settings, 'ADMIN_PHONE_NUMBER', None)
    if not admin_phone:
        logger.warning("[Alerte Admin] Aucun numéro d'administrateur configuré dans ADMIN_PHONE_NUMBER.")
        return False

    message = (
        f"[ALERTE GAZEO CRITIQUE] {nb_echecs} échecs consécutifs de paiement Mobile Money "
        f"Notchpay détectés ! Vérifiez immédiatement l'API et les webhooks Notchpay."
    )
    logger.critical(message)
    sms_service = TwilioSMSService()
    return sms_service.send_sms(admin_phone, message)

