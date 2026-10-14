from django.conf import settings
from django.db import models


class StatutCommande(models.TextChoices):
    EN_ATTENTE = 'EN_ATTENTE', 'En attente'
    ACCEPTEE = 'ACCEPTEE', 'Acceptée par le gérant'
    EN_LIVRAISON = 'EN_LIVRAISON', 'En cours de livraison'
    LIVREE = 'LIVREE', 'Livrée'
    ANNULEE = 'ANNULEE', 'Annulée'


class Commande(models.Model):
    client = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='commandes_client',
        help_text="Client qui a passé la commande"
    )
    depot = models.ForeignKey(
        'depots.Depot',
        on_delete=models.PROTECT,
        related_name='commandes',
        help_text="Dépôt fournisseur"
    )
    livreur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='commandes_livreur',
        limit_choices_to={'role': 'LIVREUR'},
        help_text="Livreur assigné"
    )

    quantite_6kg = models.PositiveIntegerField(default=0, help_text="Nombre de bouteilles 6kg")
    quantite_12kg = models.PositiveIntegerField(default=0, help_text="Nombre de bouteilles 12.5kg")

    montant_total = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Montant total de la commande (gaz + livraison en FCFA)"
    )
    frais_livraison = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=1000.00,
        help_text="Frais de livraison appliqués (FCFA)"
    )

    statut = models.CharField(
        max_length=20,
        choices=StatutCommande.choices,
        default=StatutCommande.EN_ATTENTE,
        help_text="État d'avancement de la commande"
    )

    adresse_livraison = models.CharField(max_length=255, help_text="Adresse ou repère de livraison")
    latitude_livraison = models.FloatField(help_text="Latitude GPS de destination")
    longitude_livraison = models.FloatField(help_text="Longitude GPS de destination")

    code_confirmation = models.CharField(
        max_length=6,
        help_text="Code OTP 6 chiffres communiqué au client pour valider la livraison"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Commande"
        verbose_name_plural = "Commandes"
        ordering = ['-created_at']

    def __str__(self):
        return f"Commande #{self.id} - {self.client.telephone} ({self.get_statut_display()})"


class SuiviPosition(models.Model):
    commande = models.ForeignKey(
        Commande,
        on_delete=models.CASCADE,
        related_name='positions',
        help_text="Commande suivie"
    )
    livreur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='positions_enregistrees',
        help_text="Livreur émetteur du point GPS"
    )
    latitude = models.FloatField(help_text="Latitude GPS temps réel")
    longitude = models.FloatField(help_text="Longitude GPS temps réel")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Suivi de position"
        verbose_name_plural = "Suivis de position"
        ordering = ['-timestamp']

    def __str__(self):
        return f"Pos Livreur {self.livreur.telephone} (Cmd #{self.commande.id}) à {self.timestamp.strftime('%H:%M:%S')}"
