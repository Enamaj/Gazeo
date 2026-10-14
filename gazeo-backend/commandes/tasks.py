import logging
from datetime import timedelta
from celery import shared_task
from django.conf import settings
from django.utils import timezone

from auth_user.services.sms_service import TwilioSMSService
from commandes.models import Commande, StatutCommande

logger = logging.getLogger(__name__)


@shared_task(name="commandes.verifier_commandes_bloquees")
def verifier_commandes_bloquees_task() -> int:
    """
    Vérifie les commandes payées/acceptées en attente d'un livreur depuis plus de 30 minutes.
    Déclenche une alerte SMS critique à l'administrateur.
    """
    seuil_temps = timezone.now() - timedelta(minutes=30)
    commandes_bloquees = Commande.objects.filter(
        statut__in=[StatutCommande.EN_ATTENTE, StatutCommande.ACCEPTEE],
        livreur__isnull=True,
        created_at__lt=seuil_temps
    )

    count = commandes_bloquees.count()
    if count == 0:
        logger.info("[Surveillance Commandes] Aucune commande bloquée sans livreur.")
        return 0

    premieres = list(commandes_bloquees.values_list('id', flat=True)[:3])
    ids_str = ", ".join(f"#{cid}" for cid in premieres)

    admin_phone = getattr(settings, 'ADMIN_PHONE_NUMBER', None)
    message = (
        f"[ALERTE GAZEO] {count} commande(s) bloquée(s) depuis plus de 30 min sans livreur "
        f"à Yaoundé ({ids_str}). Assignez des coursiers d'urgence !"
    )
    logger.warning(message)

    if admin_phone:
        sms_service = TwilioSMSService()
        sms_service.send_sms(admin_phone, message)

    return count

