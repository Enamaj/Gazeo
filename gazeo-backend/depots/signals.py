import logging
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Depot
from .services.cache_service import invalider_cache_depot

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Depot)
def depot_post_save(sender, instance, **kwargs):
    """
    Invalide automatiquement les caches lors de la modification d'un dépôt (via API ou Admin).
    """
    invalider_cache_depot(instance.id)


@receiver(post_delete, sender=Depot)
def depot_post_delete(sender, instance, **kwargs):
    """
    Invalide les caches lors de la suppression d'un dépôt.
    """
    invalider_cache_depot(instance.id)

