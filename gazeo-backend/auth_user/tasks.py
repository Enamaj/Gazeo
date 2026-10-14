import logging
from celery import shared_task
from .services.sms_service import TwilioSMSService

logger = logging.getLogger(__name__)


@shared_task(name="auth_user.envoyer_sms_async")
def envoyer_sms_async(telephone: str, message: str) -> bool:
    """
    Tâche asynchrone Celery pour l'envoi de SMS (évite de bloquer les requêtes HTTP).
    """
    logger.info(f"[Celery Task] Envoi SMS asynchrone vers {telephone}")
    sms_service = TwilioSMSService()
    return sms_service.send_sms(telephone, message)

