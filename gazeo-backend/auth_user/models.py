from cloudinary.models import CloudinaryField
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class UserRole(models.TextChoices):
    CLIENT = 'CLIENT', 'Client'
    GERANT = 'GERANT', 'Gérant de dépôt'
    LIVREUR = 'LIVREUR', 'Livreur'
    ADMIN = 'ADMIN', 'Administrateur'


class StatutKYC(models.TextChoices):
    EN_ATTENTE = 'EN_ATTENTE', 'En attente de validation'
    VALIDE = 'VALIDE', 'Validé'
    REJETE = 'REJETE', 'Rejeté'


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
        help_text="Rôle de l'utilisateur"
    )
    fcm_token = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Token Firebase Cloud Messaging pour les notifications"
    )
    points_fidelite = models.PositiveIntegerField(
        default=0,
        help_text="Solde de points fidélité"
    )

    # Champs de gestion OTP d'authentification
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)
    is_verified = models.BooleanField(
        default=False,
        help_text="Indique si le numéro de téléphone a été vérifié par OTP"
    )

    USERNAME_FIELD = 'telephone'
    REQUIRED_FIELDS = ['username']

    class Meta:
        verbose_name = "Utilisateur"
        verbose_name_plural = "Utilisateurs"

    def __str__(self):
        return f"{self.telephone} ({self.get_role_display()})"


class GerantKYC(models.Model):
    gerant = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='kyc',
        limit_choices_to={'role': UserRole.GERANT},
        help_text="Gérant associé au dossier KYC"
    )
    cni_recto = CloudinaryField('cni_recto', folder='gazeo/kyc', blank=True, null=True)
    cni_verso = CloudinaryField('cni_verso', folder='gazeo/kyc', blank=True, null=True)
    photo_depot = CloudinaryField('photo_depot', folder='gazeo/kyc', blank=True, null=True)
    statut = models.CharField(
        max_length=20,
        choices=StatutKYC.choices,
        default=StatutKYC.EN_ATTENTE,
        help_text="Statut de validation du dossier"
    )
    raison_rejet = models.TextField(blank=True, null=True, help_text="Raison en cas de rejet")
    date_soumission = models.DateTimeField(auto_now_add=True)
    date_decision = models.DateTimeField(blank=True, null=True)
    valide_par = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='kyc_decisions',
        help_text="Administrateur ayant validé ou rejeté le dossier"
    )

    class Meta:
        verbose_name = "Dossier KYC Gérant"
        verbose_name_plural = "Dossiers KYC Gérants"
        ordering = ['-date_soumission']

    def __str__(self):
        return f"KYC {self.gerant.telephone} ({self.get_statut_display()})"
