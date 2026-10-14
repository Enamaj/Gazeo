from django.conf import settings
from django.db import models


class TypeTransaction(models.TextChoices):
    GAIN = 'GAIN', 'Gain de points'
    UTILISATION = 'UTILISATION', 'Utilisation de points'


class Transaction(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transactions_fidelite',
        help_text="Utilisateur bénéficiaire ou débiteur"
    )
    commande = models.ForeignKey(
        'commandes.Commande',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='transactions_fidelite',
        help_text="Commande liée à l'opération de fidélité"
    )
    points = models.IntegerField(help_text="Quantité de points (positif pour gain, négatif pour utilisation)")
    type = models.CharField(
        max_length=20,
        choices=TypeTransaction.choices,
        help_text="Type d'opération fidélité"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Transaction fidélité"
        verbose_name_plural = "Transactions fidélité"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.telephone} - {self.get_type_display()} ({self.points} pts)"
