import csv
import os
from decimal import Decimal
from pathlib import Path
from django.core.management.base import BaseCommand, CommandError
from django.contrib.gis.geos import Point
from auth_user.models import User, UserRole
from depots.models import Depot, MarqueGaz
from depots.services.cache_service import invalider_cache_depot


class Command(BaseCommand):
    help = "Importe en masse les dépôts de gaz de Yaoundé depuis un fichier CSV (Prompt 9.3)"

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default='data/depots_yaounde.csv',
            help="Chemin vers le fichier CSV contenant les dépôts à importer"
        )

    def handle(self, *args, **options):
        file_path_str = options['file']
        file_path = Path(file_path_str)

        # Chercher également par rapport à la racine backend
        if not file_path.exists():
            base_dir = Path(__file__).resolve().parent.parent.parent.parent
            file_path = base_dir / file_path_str

        if not file_path.exists():
            raise CommandError(f"Le fichier CSV spécifié est introuvable : {file_path}")

        self.stdout.write(f"Début de l'importation depuis : {file_path}")

        depots_crees = 0
        depots_mis_a_jour = 0
        gerants_crees = 0

        # Mapper les marques du CSV vers MarqueGaz
        marque_map = {
            'TOTAL': MarqueGaz.TOTAL,
            'TRADEX': MarqueGaz.TRADEX,
            'CAMGAZ': MarqueGaz.CAMGAZ,
            'AUTRE': MarqueGaz.AUTRE,
        }

        with open(file_path, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                nom = row['nom'].strip()
                lat = float(row['latitude'].strip())
                lon = float(row['longitude'].strip())
                telephone = row['telephone'].strip()
                quartier = row['quartier'].strip()
                marque_raw = row['marque'].strip().upper()
                marque = marque_map.get(marque_raw, MarqueGaz.AUTRE)

                # 1. Créer ou récupérer le compte gérant dédié au dépôt
                gerant_tel = telephone
                gerant_username = f"gerant_{telephone.replace('+', '')}"
                gerant, g_created = User.objects.get_or_create(
                    telephone=gerant_tel,
                    defaults={
                        'username': gerant_username,
                        'first_name': 'Gérant',
                        'last_name': nom,
                        'role': UserRole.GERANT,
                        'is_verified': True,
                        'is_active': True,
                    }
                )
                if g_created:
                    gerant.set_password("GazeoPass2026!")
                    gerant.save()
                    gerants_crees += 1

                # 2. Créer ou mettre à jour le Dépôt PostGIS
                depot, created = Depot.objects.update_or_create(
                    telephone=telephone,
                    defaults={
                        'nom': nom,
                        'adresse': f"Rue principale, {quartier}, Yaoundé",
                        'quartier': quartier,
                        'gerant': gerant,
                        'marque': marque,
                        'stock_6kg': 25,
                        'stock_12kg': 25,
                        'prix_6kg': Decimal('3500.00'),
                        'prix_12kg': Decimal('7000.00'),
                        'localisation': Point(lon, lat, srid=4326),
                        'est_actif': True,
                        'statut_kyc': 'VALIDE',
                    }
                )

                invalider_cache_depot(depot.id)

                if created:
                    depots_crees += 1
                else:
                    depots_mis_a_jour += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"\n🎉 Importation terminée avec succès !\n"
                f"  • {depots_crees} nouveaux dépôts créés\n"
                f"  • {depots_mis_a_jour} dépôts mis à jour\n"
                f"  • {gerants_crees} nouveaux comptes gérants initialisés\n"
                f"  • Total dépôts opérationnels à Yaoundé : {Depot.objects.filter(est_actif=True).count()}"
            )
        )

