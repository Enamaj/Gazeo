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

    # Répartition financière GAZEO en FCFA (IntegerField)
    prix_bouteille = models.IntegerField(
        default=0,
        help_text="Prix fixe réglementé de la bouteille de gaz (100% au gérant, en FCFA)"
    )
    frais_livraison = models.IntegerField(
        default=1500,
        help_text="Frais de livraison calculés selon la distance GPS PostGIS (en FCFA)"
    )
    commission_gazeo = models.IntegerField(
        default=300,
        help_text="Commission GAZEO (20% des frais de livraison en FCFA)"
    )
    montant_livreur = models.IntegerField(
        default=1200,
        help_text="Part du livreur (80% des frais de livraison en FCFA)"
    )
    montant_total_client = models.IntegerField(
        default=0,
        help_text="Montant total payé par le client : prix_bouteille + frais_livraison (en FCFA)"
    )
    montant_gerant = models.IntegerField(
        default=0,
        help_text="Montant reversé au gérant : prix_bouteille + montant_livreur (en FCFA)"
    )
    # Champ rétrocompatible
    montant_total = models.IntegerField(
        default=0,
        help_text="Total payé par le client (alias FCFA)"
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

    def get_distance_km(self) -> float:
        """
        Calcule la distance réelle en km entre le dépôt et l'adresse client :
        1. Utilise la géométrie PostGIS si disponible
        2. Fallback direct sur la formule Haversine (Yaoundé)
        """
        if not self.depot or self.latitude_livraison is None or self.longitude_livraison is None:
            return 2.5

        try:
            from django.contrib.gis.geos import Point
            pt_client = Point(float(self.longitude_livraison), float(self.latitude_livraison), srid=4326)
            if self.depot.localisation:
                dist = self.depot.localisation.distance(pt_client)
                # Si calcul en degrés géographiques, convertir en km approximatif
                if dist < 1.0:
                    dist_km = dist * 111.32
                else:
                    dist_km = dist / 1000.0
                return round(dist_km, 2)
        except Exception:
            pass

        import math
        lat1 = self.depot.latitude or 3.8667
        lon1 = self.depot.longitude or 11.5167
        lat2 = float(self.latitude_livraison)
        lon2 = float(self.longitude_livraison)

        R = 6371.0
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (math.sin(dlat / 2.0) ** 2 +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(dlon / 2.0) ** 2)
        c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
        return round(R * c, 2)

    @staticmethod
    def calculer_frais_livraison_grille(distance_km: float) -> int:
        """
        Grille officielle des frais de livraison GAZEO à Yaoundé :
        - 0 à 3 km → 1 500 FCFA
        - 3 à 6 km → 2 000 FCFA
        - 6 à 12 km → 2 500 FCFA
        """
        if distance_km <= 3.0:
            return 1500
        elif distance_km <= 6.0:
            return 2000
        elif distance_km <= 12.0:
            return 2500
        else:
            return 3000

    def calculer_repartition_financiere(self, prix_gaz: int = None, distance_km: float = None):
        """
        Implémente les règles financières officielles GAZEO :
        - prix_bouteille : prix fixe réglementé, va 100% au gérant
        - frais_livraison : calculé selon la distance (PostGIS)
        - commission_gazeo : 20% des frais_livraison
        - montant_livreur : 80% des frais_livraison
        - montant_total_client : prix_bouteille + frais_livraison
        - montant_gerant : prix_bouteille + montant_livreur
        """
        if prix_gaz is not None:
            self.prix_bouteille = int(prix_gaz)

        if distance_km is None:
            distance_km = self.get_distance_km()

        self.frais_livraison = self.calculer_frais_livraison_grille(distance_km)
        self.commission_gazeo = int(round(self.frais_livraison * 0.20))
        self.montant_livreur = self.frais_livraison - self.commission_gazeo  # Exact 80%
        self.montant_total_client = int(self.prix_bouteille) + int(self.frais_livraison)
        self.montant_gerant = int(self.prix_bouteille) + int(self.montant_livreur)
        self.montant_total = self.montant_total_client


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
