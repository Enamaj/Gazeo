from django.db import models


class MethodePaiement(models.TextChoices):
    MTN_MOMO = 'MTN_MOMO', 'MTN Mobile Money'
    ORANGE_MONEY = 'ORANGE_MONEY', 'Orange Money'


class StatutPaiement(models.TextChoices):
    PENDING = 'PENDING', 'En attente'
    SUCCESS = 'SUCCESS', 'Succès'
    FAILED = 'FAILED', 'Échoué'
    REFUNDED = 'REFUNDED', 'Remboursé'


class Paiement(models.Model):
    commande = models.OneToOneField(
        'commandes.Commande',
        on_delete=models.PROTECT,
        related_name='paiement',
        help_text="Commande associée au règlement"
    )
    reference_notchpay = models.CharField(
        max_length=100,
        unique=True,
        help_text="Référence unique de transaction générée par Notchpay"
    )
    methode = models.CharField(
        max_length=20,
        choices=MethodePaiement.choices,
        help_text="Moyen de paiement MoMo utilisé"
    )
    statut = models.CharField(
        max_length=20,
        choices=StatutPaiement.choices,
        default=StatutPaiement.PENDING,
        help_text="État du paiement"
    )
    montant = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Montant encaissé en FCFA"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Paiement"
        verbose_name_plural = "Paiements"
        ordering = ['-created_at']

    def __str__(self):
        return f"Paiement {self.reference_notchpay} ({self.get_statut_display()}) - {self.montant} FCFA"
