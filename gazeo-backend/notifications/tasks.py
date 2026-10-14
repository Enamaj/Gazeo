import logging
from datetime import timedelta
from typing import List, Dict, Any
from celery import shared_task
from django.contrib.auth import get_user_model
from django.utils import timezone
from .models import DeviceToken
from .services.fcm_service import FCMService

logger = logging.getLogger(__name__)
User = get_user_model()


@shared_task(name="notifications.envoyer_notification_fcm_async")
def envoyer_notification_fcm_async(
    user_id: int,
    titre: str,
    corps: str,
    data: Dict[str, Any] = None,
    channel_id: str = "gazeo_general"
):
    """
    Envoi asynchrone d'une notification FCM à un utilisateur.
    """
    user = User.objects.filter(pk=user_id).first()
    if not user:
        logger.warning(f"[Celery FCM] Utilisateur #{user_id} introuvable.")
        return []

    return FCMService.envoyer_notification(
        user=user,
        titre=titre,
        corps=corps,
        data=data,
        channel_id=channel_id
    )


@shared_task(name="notifications.envoyer_notifications_fcm_batch")
def envoyer_notifications_fcm_batch(notifications: List[Dict[str, Any]]) -> int:
    """
    Envoi en batch de notifications FCM pour optimiser les performances.
    notifications = [{'user_id': 1, 'titre': '...', 'corps': '...', 'data': {...}}, ...]
    """
    total_envoyes = 0
    for item in notifications:
        user_id = item.get('user_id')
        user = User.objects.filter(pk=user_id).first()
        if user:
            FCMService.envoyer_notification(
                user=user,
                titre=item.get('titre', 'GAZEO'),
                corps=item.get('corps', ''),
                data=item.get('data')
            )
            total_envoyes += 1
    logger.info(f"[Celery FCM Batch] {total_envoyes} notifications traitées.")
    return total_envoyes


@shared_task(name="notifications.nettoyer_tokens_fcm_expires")
def nettoyer_tokens_fcm_expires_task() -> int:
    """
    Tâche récurrente de nettoyage des tokens inactifs ou non mis à jour depuis plus de 60 jours.
    """
    limite = timezone.now() - timedelta(days=60)
    count, _ = DeviceToken.objects.filter(is_active=False, updated_at__lt=limite).delete()
    logger.info(f"[Celery] {count} anciens tokens FCM nettoyés.")
    return count

