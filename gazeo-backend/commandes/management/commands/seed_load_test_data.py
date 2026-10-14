from decimal import Decimal
import random
from django.core.management.base import BaseCommand
from django.contrib.gis.geos import Point
from auth_user.models import User, UserRole
from depots.models import Depot, MarqueGaz


class Command(BaseCommand):
    help = "Génère des données de test de charge (50 dépôts à Yaoundé, clients et livreurs)"

    def handle(self, *args, **options):
        self.stdout.write("Initialisation des données pour les tests de charge...")

        # 1. Créer le gérant principal pour les dépôts
        gerant, _ = User.objects.get_or_create(
            telephone="+237655000001",
            defaults={
                "username": "gerant_loadtest",
                "first_name": "Gérant",
                "last_name": "Charge Test",
                "role": UserRole.GERANT,
                "is_verified": True,
                "is_active": True,
            }
        )
        gerant.set_password("GazeoTestPass2026!")
        gerant.save()

        # 2. Créer 10 clients de test
        clients = []
        for i in range(1, 11):
            tel = f"+23769900{i:04d}"
            c, _ = User.objects.get_or_create(
                telephone=tel,
                defaults={
                    "username": f"client_loadtest_{i}",
                    "first_name": "Client",
                    "last_name": f"Test {i}",
                    "role": UserRole.CLIENT,
                    "is_verified": True,
                    "is_active": True,
                }
            )
            c.set_password("GazeoTestPass2026!")
            c.save()
            clients.append(c)

        # 3. Créer 5 livreurs de test
        livreurs = []
        for i in range(1, 6):
            tel = f"+23767700{i:04d}"
            l, _ = User.objects.get_or_create(
                telephone=tel,
                defaults={
                    "username": f"livreur_loadtest_{i}",
                    "first_name": "Livreur",
                    "last_name": f"Test {i}",
                    "role": UserRole.LIVREUR,
                    "is_verified": True,
                    "is_active": True,
                    "est_disponible": True,
                }
            )
            l.set_password("GazeoTestPass2026!")
            l.save()
            livreurs.append(l)

        # 4. Générer 50 dépôts géolocalisés à Yaoundé
        quartiers = [
            "Bastos", "Mokolo", "Tsinga", "Essos", "Biyem-Assi",
            "Omnisports", "Nlongkak", "Mendong", "Emana", "Mvan",
            "Simbock", "Melen", "Acacia", "Kondengui", "Ngoa-Ekélé"
        ]
        marques = [
            MarqueGaz.TOTAL,
            MarqueGaz.TRADEX,
            MarqueGaz.CAMGAZ,
            MarqueGaz.AUTRE
        ]

        depots_crees = 0
        for i in range(1, 51):
            nom_depot = f"Dépôt Gaz Yaoundé #{i} ({random.choice(quartiers)})"
            quartier = random.choice(quartiers)
            # Yaoundé coordonnées approximatives: lat [3.82, 3.90], lon [11.48, 11.55]
            lat = round(random.uniform(3.8200, 3.9000), 5)
            lon = round(random.uniform(11.4800, 11.5500), 5)

            depot, created = Depot.objects.get_or_create(
                telephone=f"+23768800{i:04d}",
                defaults={
                    "nom": nom_depot,
                    "adresse": f"Rue des palmiers #{i}, {quartier}",
                    "quartier": quartier,
                    "gerant": gerant,
                    "marque": random.choice(marques),
                    "stock_6kg": 200,
                    "stock_12kg": 200,
                    "prix_6kg": Decimal("3500.00"),
                    "prix_12kg": Decimal("7000.00"),
                    "localisation": Point(lon, lat, srid=4326),
                    "est_actif": True,
                    "statut_kyc": "VALIDE",
                }
            )
            if created:
                depots_crees += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Succès ! {depots_crees} nouveaux dépôts créés (Total dépôts actifs : {Depot.objects.filter(est_actif=True).count()}).\n"
                f"10 clients et 5 livreurs prêts pour le test de charge."
            )
        )
