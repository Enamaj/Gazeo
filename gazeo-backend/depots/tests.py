from django.contrib.gis.geos import Point
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from auth_user.models import User, UserRole
from depots.models import Depot, MarqueGaz, StatutKYC
from notation.models import Avis
from commandes.models import Commande, StatutCommande


class DepotsAPITests(APITestCase):
    def setUp(self):
        # Création des utilisateurs
        self.client_user = User.objects.create_user(
            username="+237699111111",
            telephone="+237699111111",
            password="Password123!",
            role=UserRole.CLIENT,
            is_verified=True,
            is_active=True
        )
        self.gerant_user = User.objects.create_user(
            username="+237677222222",
            telephone="+237677222222",
            password="Password123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True
        )
        self.autre_gerant = User.objects.create_user(
            username="+237655333333",
            telephone="+237655333333",
            password="Password123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True
        )

        # Centre de Yaoundé (Poste Centrale) : lat=3.8667, lon=11.5167
        # Dépôt 1 : Bastos (Yaoundé, ~2.5 km du centre)
        self.depot_bastos = Depot.objects.create(
            nom="Dépôt Gaz Bastos Ambassade",
            adresse="Avenue Bastos, face ambassade",
            quartier="Bastos",
            telephone="+237677222222",
            localisation=Point(11.5180, 3.8850, srid=4326),  # lon, lat
            gerant=self.gerant_user,
            marque=MarqueGaz.TOTAL,
            stock_6kg=15,
            stock_12kg=25,
            prix_6kg=3000.00,
            prix_12kg=6500.00,
            statut_kyc=StatutKYC.VALIDE,
            est_actif=True
        )

        # Dépôt 2 : Melen (Yaoundé, ~3 km du centre)
        self.depot_melen = Depot.objects.create(
            nom="Dépôt Tradex Melen Polytechnique",
            adresse="Carrefour Melen",
            quartier="Melen",
            telephone="+237655333333",
            localisation=Point(11.4980, 3.8600, srid=4326),
            gerant=self.autre_gerant,
            marque=MarqueGaz.TRADEX,
            stock_6kg=0,
            stock_12kg=0,  # En rupture de stock
            prix_6kg=3000.00,
            prix_12kg=6500.00,
            statut_kyc=StatutKYC.VALIDE,
            est_actif=True
        )

        self.gerant_douala = User.objects.create_user(
            username="+237633444444",
            telephone="+237633444444",
            password="Password123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True
        )

        # Dépôt 3 : Douala (Akwa, ~200 km de Yaoundé) - Ne doit pas être retourné dans un rayon de 5km
        self.depot_douala = Depot.objects.create(
            nom="Dépôt Camgaz Douala Akwa",
            adresse="Boulevard de la Liberté",
            quartier="Akwa",
            telephone="+237633444444",
            localisation=Point(9.7042, 4.0511, srid=4326),
            gerant=self.gerant_douala,
            marque=MarqueGaz.CAMGAZ,
            stock_6kg=30,
            stock_12kg=40,
            statut_kyc=StatutKYC.VALIDE,
            est_actif=True
        )

    def test_depots_proches_st_dwithin_and_distance(self):
        """Le filtre spatial ST_DWithin retourne les dépôts dans le rayon avec la distance calculée."""
        url = reverse('depots:depots_proches')
        # Requête depuis le centre de Yaoundé avec stock_uniquement=false pour voir tous les dépôts proches
        response = self.client.get(url, {
            'lat': 3.8667,
            'lon': 11.5167,
            'rayon': 5000,
            'stock_uniquement': 'false'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        depots_returned = response.data['depots']
        noms = [d['nom'] for d in depots_returned]

        # Les dépôts de Yaoundé (Bastos et Melen) sont dans le rayon de 5km
        self.assertIn("Dépôt Gaz Bastos Ambassade", noms)
        self.assertIn("Dépôt Tradex Melen Polytechnique", noms)
        # Le dépôt de Douala (~200km) doit être exclu
        self.assertNotIn("Dépôt Camgaz Douala Akwa", noms)

        # Vérifier que la distance est calculée et positive
        self.assertIsNotNone(depots_returned[0]['distance_metres'])
        self.assertGreater(depots_returned[0]['distance_metres'], 0)

    def test_depots_proches_filter_stock_disponible(self):
        """Par défaut, les dépôts en rupture totale de stock sont filtrés."""
        url = reverse('depots:depots_proches')
        response = self.client.get(url, {
            'lat': 3.8667,
            'lon': 11.5167,
            'rayon': 5000,
            'stock_uniquement': 'true'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        noms = [d['nom'] for d in response.data['depots']]
        self.assertIn("Dépôt Gaz Bastos Ambassade", noms)
        self.assertNotIn("Dépôt Tradex Melen Polytechnique", noms)  # Stock = 0 exclu

    def test_depots_proches_filter_by_marque(self):
        """Le filtre par marque (TRADEX vs TOTAL) fonctionne."""
        url = reverse('depots:depots_proches')
        response = self.client.get(url, {
            'lat': 3.8667,
            'lon': 11.5167,
            'rayon': 5000,
            'marque': 'TOTAL',
            'stock_uniquement': 'false'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        for depot in response.data['depots']:
            self.assertEqual(depot['marque'], MarqueGaz.TOTAL)

    def test_depot_detail_endpoint(self):
        """L'endpoint /depots/{id}/ retourne la fiche complète avec note et avis."""
        # Ajouter un avis client
        Commande.objects.create(
            id=101,
            client=self.client_user,
            depot=self.depot_bastos,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=4000.00,
            adresse_livraison="Bastos Rue 12",
            latitude_livraison=3.886,
            longitude_livraison=11.519,
            code_confirmation="123456"
        )
        Avis.objects.create(
            commande_id=101,
            client=self.client_user,
            depot=self.depot_bastos,
            note=5,
            commentaire="Livraison ultra rapide et livreur courtois !"
        )

        url = reverse('depots:depot_detail', kwargs={'pk': self.depot_bastos.pk})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['nom'], self.depot_bastos.nom)
        self.assertEqual(response.data['note_moyenne'], 5.0)
        self.assertEqual(response.data['total_avis'], 1)
        self.assertEqual(len(response.data['derniers_avis']), 1)

    def test_gerant_mon_depot_permissions(self):
        """Seul le gérant authentifié peut accéder à /gerants/mon-depot/."""
        url = reverse('gerants:gerant_mon_depot')

        # Requête anonyme -> 401
        res_anon = self.client.get(url)
        self.assertEqual(res_anon.status_code, status.HTTP_401_UNAUTHORIZED)

        # Requête client -> 403 Forbidden
        self.client.force_authenticate(user=self.client_user)
        res_client = self.client.get(url)
        self.assertEqual(res_client.status_code, status.HTTP_403_FORBIDDEN)

        # Requête gérant -> 200 OK
        self.client.force_authenticate(user=self.gerant_user)
        res_gerant = self.client.get(url)
        self.assertEqual(res_gerant.status_code, status.HTTP_200_OK)
        self.assertEqual(res_gerant.data['nom'], self.depot_bastos.nom)

    def test_gerant_update_stock(self):
        """Le gérant peut mettre à jour rapidement ses stocks de bouteilles."""
        url = reverse('gerants:gerant_stock_update')
        self.client.force_authenticate(user=self.gerant_user)

        data = {"stock_6kg": 42, "stock_12kg": 18}
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['stock_6kg'], 42)
        self.assertEqual(response.data['stock_12kg'], 18)
        self.assertEqual(response.data['stock_disponible'], 60)

        self.depot_bastos.refresh_from_db()
        self.assertEqual(self.depot_bastos.stock_6kg, 42)
        self.assertEqual(self.depot_bastos.stock_12kg, 18)

    def test_gerant_commandes_list(self):
        """Le gérant peut lister les commandes adressées à son dépôt."""
        Commande.objects.create(
            id=102,
            client=self.client_user,
            depot=self.depot_bastos,
            quantite_6kg=2,
            quantite_12kg=1,
            montant_total=13500.00,
            statut=StatutCommande.EN_ATTENTE,
            adresse_livraison="Bastos Rue 15",
            latitude_livraison=3.887,
            longitude_livraison=11.517,
            code_confirmation="654321"
        )
        url = reverse('gerants:gerant_commandes')
        self.client.force_authenticate(user=self.gerant_user)

        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['commandes'][0]['id'], 102)
