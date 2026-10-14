from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models


class Avis(models.Model):
    commande = models.ForeignKey(
        'commandes.Commande',
        on_delete=models.CASCADE,
        related_name='avis',
        help_text="Commande objet de l'évaluation"
    )
    client = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='avis_donnes',
        help_text="Client auteur de l'avis"
    )
    depot = models.ForeignKey(
        'depots.Depot',
        on_delete=models.CASCADE,
        related_name='avis',
        help_text="Dépôt évalué"
    )
    note = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Note sur une échelle de 1 à 5 étoiles"
    )
    commentaire = models.TextField(
        blank=True,
        help_text="Commentaire libre sur le service"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Avis client"
        verbose_name_plural = "Avis clients"
        ordering = ['-created_at']

    def __str__(self):
        return f"Avis {self.note}/5 par {self.client.telephone} pour {self.depot.nom}"
