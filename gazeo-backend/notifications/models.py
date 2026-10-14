from django.conf import settings
from django.db import models


class DeviceToken(models.Model):
    DEVICE_TYPES = [
        ('android', 'Android'),
        ('ios', 'iOS'),
        ('web', 'Web'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='fcm_devices'
    )
    token = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="Token d'enregistrement Firebase Cloud Messaging"
    )
    device_type = models.CharField(
        max_length=20,
        choices=DEVICE_TYPES,
        default='android',
        help_text="Plateforme de l'appareil"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Statut actif du token (désactivé si invalide ou 404)"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Token FCM Appareil"
        verbose_name_plural = "Tokens FCM Appareils"
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.user.telephone} - {self.device_type} ({self.token[:15]}...)"


class NotificationLog(models.Model):
    STATUT_CHOICES = [
        ('ENVOYE', 'Envoyé avec succès'),
        ('ECHEC', 'Échec de transmission'),
        ('SIMULE', 'Simulé en environnement de développement'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications_recues'
    )
    titre = models.CharField(max_length=255)
    corps = models.TextField()
    data = models.JSONField(default=dict, blank=True)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='ENVOYE')
    message_id = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Journal de Notification"
        verbose_name_plural = "Journaux de Notifications"
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.statut}] {self.titre} -> {self.user.telephone} ({self.created_at.strftime('%d/%m/%Y %H:%M')})"
