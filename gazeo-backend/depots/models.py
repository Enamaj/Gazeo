from django.conf import settings
from django.db import models


class MarqueGaz(models.TextChoices):
    TRADEX = 'TRADEX', 'Tradex'
    TOTAL = 'TOTAL', 'TotalEnergies'
    CAMGAZ = 'CAMGAZ', 'Camgaz'
    AUTRE = 'AUTRE', 'Autre marque'


class StatutKYC(models.TextChoices):
    EN_ATTENTE = 'EN_ATTENTE', 'En attente de validation'
    VALIDE = 'VALIDE', 'Validé'
    REJETE = 'REJETE', 'Rejeté'


class Depot(models.Model):
    nom = models.CharField(max_length=150, help_text="Nom commercial du dépôt")
    adresse = models.CharField(max_length=255, help_text="Adresse descriptive")
    quartier = models.CharField(max_length=100, help_text="Quartier à Yaoundé (ex: Bastos, Melen, Biyem-Assi)")
    telephone = models.CharField(max_length=20, help_text="Téléphone de contact du dépôt")

    # Coordonnées géographiques (migrées vers PostGIS PointField en Phase 2)
    latitude = models.FloatField(help_text="Latitude GPS (ex: 3.8667)")
    longitude = models.FloatField(help_text="Longitude GPS (ex: 11.5167)")

    gerant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='depots',
        limit_choices_to={'role': 'GERANT'},
        help_text="Gérant propriétaire du dépôt"
    )

    marque = models.CharField(
        max_length=20,
        choices=MarqueGaz.choices,
        default=MarqueGaz.TRADEX,
        help_text="Marque principale distribuée"
    )

    stock_6kg = models.PositiveIntegerField(default=0, help_text="Quantité en stock de bouteilles 6kg")
    stock_12kg = models.PositiveIntegerField(default=0, help_text="Quantité en stock de bouteilles 12.5kg")

    prix_6kg = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=3000.00,
        help_text="Prix unitaire de la bouteille 6kg (FCFA)"
    )
    prix_12kg = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=6500.00,
        help_text="Prix unitaire de la bouteille 12.5kg (FCFA)"
    )

    statut_kyc = models.CharField(
        max_length=20,
        choices=StatutKYC.choices,
        default=StatutKYC.EN_ATTENTE,
        help_text="Statut de vérification légale"
    )
    est_actif = models.BooleanField(
        default=False,
        help_text="Visibilité publique du dépôt sur la carte"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Dépôt de gaz"
        verbose_name_plural = "Dépôts de gaz"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.nom} - {self.quartier} ({self.get_marque_display()})"
