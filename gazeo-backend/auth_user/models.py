from django.contrib.auth.models import AbstractUser
from django.db import models


class UserRole(models.TextChoices):
    CLIENT = 'CLIENT', 'Client'
    GERANT = 'GERANT', 'Gérant de dépôt'
    LIVREUR = 'LIVREUR', 'Livreur'
    ADMIN = 'ADMIN', 'Administrateur'


class User(AbstractUser):
    username = models.CharField(max_length=150, unique=True, blank=True, null=True)
    telephone = models.CharField(
        max_length=20,
        unique=True,
        help_text="Numéro de téléphone principal (ex: +237 6XX XX XX XX)"
    )
    role = models.CharField(
        max_length=10,
        choices=UserRole.choices,
        default=UserRole.CLIENT,
        help_text="Rôle utilisateur"
    )
    fcm_token = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Token Firebase Cloud Messaging pour les notifications"
    )
    points_fidelite = models.PositiveIntegerField(
        default=0,
        help_text="Points de fidélité accumulés"
    )

    USERNAME_FIELD = 'telephone'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return f"{self.telephone} ({self.get_role_display()})"
