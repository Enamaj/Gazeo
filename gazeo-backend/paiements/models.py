from decimal import Decimal
from django.conf import settings
from django.db import models


class MethodePaiement(models.TextChoices):
    MTN_MOMO = 'MTN_MOMO', 'MTN Mobile Money'
    ORANGE_MONEY = 'ORANGE_MONEY', 'Orange Money'


class StatutPaiement(models.TextChoices):
    PENDING = 'PENDING', 'En attente'
    SUCCESS = 'SUCCESS', 'Succès'
    FAILED = 'FAILED', 'Échoué'
    REFUNDED = 'REFUNDED', 'Remboursé'


class StatutVirement(models.TextChoices):
    EN_ATTENTE = 'EN_ATTENTE', 'En attente de virement'
    VIRE = 'VIRE', 'Viré avec succès'
    ECHOUE = 'ECHOUE', 'Échoué'


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
        default=MethodePaiement.MTN_MOMO,
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

    # Calculs de commission GAZEO (1,5% en production)
    commission_gazeo = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Commission prélevée par GAZEO (1,5%)"
    )
    montant_net_gerant = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Revenu net revenant au gérant"
    )

    # Traçabilité des remboursements (Prompt 5.2)
    rembourse_at = models.DateTimeField(null=True, blank=True)
    rembourse_par = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='remboursements_effectues',
        limit_choices_to={'is_staff': True}
    )
    motif_remboursement = models.TextField(blank=True, null=True)

    raw_response = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Paiement"
        verbose_name_plural = "Paiements"
        ordering = ['-created_at']

    def __str__(self):
        return f"Paiement {self.reference_notchpay} ({self.get_statut_display()}) - {self.montant} FCFA"

    def calculer_commissions(self):
        """Calcule la commission GAZEO de 1,5% et le net gérant."""
        self.commission_gazeo = round(self.montant * Decimal('0.015'), 2)
        self.montant_net_gerant = round(self.montant - self.commission_gazeo, 2)


class VirementHebdomadaire(models.Model):
    gerant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='virements_hebdomadaires',
        limit_choices_to={'role': 'GERANT'}
    )
    periode_debut = models.DateField()
    periode_fin = models.DateField()
    total_brut = models.DecimalField(max_digits=12, decimal_places=2)
    commission_gazeo = models.DecimalField(max_digits=12, decimal_places=2)
    net_a_verser = models.DecimalField(max_digits=12, decimal_places=2)
    statut = models.CharField(
        max_length=20,
        choices=StatutVirement.choices,
        default=StatutVirement.EN_ATTENTE
    )
    date_virement = models.DateTimeField(auto_now_add=True)
    reference_virement = models.CharField(max_length=100, blank=True, null=True)

    class Meta:
        verbose_name = "Virement Hebdomadaire Gérant"
        verbose_name_plural = "Virements Hebdomadaires Gérants"
        ordering = ['-date_virement']

    def __str__(self):
        return f"Virement {self.gerant.telephone} ({self.periode_debut} au {self.periode_fin}) : {self.net_a_verser} FCFA"
