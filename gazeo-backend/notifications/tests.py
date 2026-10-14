from django.contrib.auth import get_user_model
from django.contrib.gis.geos import Point
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from auth_user.models import UserRole
from depots.models import Depot
from commandes.models import Commande, StatutCommande
from notifications.models import DeviceToken, NotificationLog
from notifications.services.fcm_service import FCMService

User = get_user_model()


class FCMServiceTests(TestCase):
    def setUp(self):
        self.client_user = User.objects.create_user(
            username='client_fcm',
            telephone='+237699000001',
            role=UserRole.CLIENT
        )
        self.gerant_user = User.objects.create_user(
            username='gerant_fcm',
            telephone='+237699000002',
            role=UserRole.GERANT
        )
        self.livreur_user = User.objects.create_user(
            username='livreur_fcm',
            telephone='+237699000003',
            role=UserRole.LIVREUR
        )
        self.depot = Depot.objects.create(
            nom="Dépôt Bastos FCM",
            gerant=self.gerant_user,
            localisation=Point(11.51, 3.87, srid=4326),
            adresse="Bastos, Yaoundé",
            quartier="Bastos",
            telephone="+237699000002",
            stock_6kg=10,
            stock_12kg=5,
            prix_6kg=6500,
            prix_12kg=13000,
            est_actif=True
        )

    def test_enregistrer_token_multi_device(self):
        """Tester l'enregistrement multi-appareils (Android et iOS pour le même utilisateur)."""
        token1 = FCMService.enregistrer_token(self.client_user, "token_android_123", device_type="android")
        self.assertEqual(token1.device_type, "android")
        self.assertEqual(self.client_user.fcm_token, "token_android_123")

        # Second appareil
        token2 = FCMService.enregistrer_token(self.client_user, "token_ios_456", device_type="ios")
        self.assertEqual(token2.device_type, "ios")
        self.assertEqual(self.client_user.fcm_devices.count(), 2)

    def test_supprimer_token_invalide(self):
        """Tester la suppression automatique d'un token invalide."""
        FCMService.enregistrer_token(self.client_user, "bad_token_789", device_type="android")
        self.assertEqual(self.client_user.fcm_devices.count(), 1)

        FCMService.supprimer_token("bad_token_789")
        self.assertEqual(self.client_user.fcm_devices.count(), 0)
        self.client_user.refresh_from_db()
        self.assertIsNone(self.client_user.fcm_token)

    def test_notifier_client_flow(self):
        """Tester les notifications envoyées au client (confirmation, livreur en route, notation)."""
        FCMService.enregistrer_token(self.client_user, "token_client_abc", device_type="android")

        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            livreur=self.livreur_user,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=7500,
            frais_livraison=1000,
            adresse_livraison="Bastos Ambassade",
            latitude_livraison=3.88,
            longitude_livraison=11.52,
            code_confirmation="123456",
            statut=StatutCommande.ACCEPTEE
        )

        # 1. Commande confirmée
        msg_ids = FCMService.notifier_commande_confirmee(commande)
        self.assertTrue(len(msg_ids) > 0)
        log1 = NotificationLog.objects.filter(user=self.client_user, data__type="COMMANDE_CONFIRMEE").first()
        self.assertIsNotNone(log1)
        self.assertIn("Bastos", log1.titre)

        # 2. Livreur en route
        FCMService.notifier_livreur_en_route(commande, estimation_minutes=15)
        log2 = NotificationLog.objects.filter(user=self.client_user, data__type="LIVREUR_EN_ROUTE").first()
        self.assertIsNotNone(log2)
        self.assertIn("15 min", log2.corps)

        # 3. Livreur proche
        FCMService.notifier_livreur_proche(commande)
        log3 = NotificationLog.objects.filter(user=self.client_user, data__type="LIVREUR_PROCHE").first()
        self.assertIsNotNone(log3)
        self.assertIn("5 min", log3.corps)

        # 4. Demande notation
        FCMService.notifier_demande_notation(commande)
        log4 = NotificationLog.objects.filter(user=self.client_user, data__type="NOTATION").first()
        self.assertIsNotNone(log4)

    def test_notifier_gerant_flow(self):
        """Tester les alertes envoyées au gérant (nouvelle commande, stock faible)."""
        FCMService.enregistrer_token(self.gerant_user, "token_gerant_xyz", device_type="android")

        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            quantite_6kg=2,
            quantite_12kg=1,
            montant_total=27000,
            frais_livraison=1000,
            adresse_livraison="Melen Polytechnique",
            latitude_livraison=3.86,
            longitude_livraison=11.50,
            code_confirmation="654321",
            statut=StatutCommande.EN_ATTENTE
        )

        # 1. Nouvelle commande
        FCMService.notifier_nouvelle_commande(commande)
        log1 = NotificationLog.objects.filter(user=self.gerant_user, data__type="NOUVELLE_COMMANDE").first()
        self.assertIsNotNone(log1)
        self.assertIn("3 bouteille(s)", log1.titre)

        # 2. Alerte stock faible
        FCMService.notifier_stock_faible(self.depot, type_bouteille="6kg", stock_restant=2)
        log2 = NotificationLog.objects.filter(user=self.gerant_user, data__type="STOCK_FAIBLE").first()
        self.assertIsNotNone(log2)
        self.assertIn("2 bouteilles 6kg", log2.corps)

    def test_notifier_livreur_flow(self):
        """Tester les alertes envoyées au livreur (nouvelle mission, annulation)."""
        FCMService.enregistrer_token(self.livreur_user, "token_livreur_999", device_type="android")

        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            livreur=self.livreur_user,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=7500,
            frais_livraison=1000,
            adresse_livraison="Bastos",
            latitude_livraison=3.88,
            longitude_livraison=11.52,
            code_confirmation="123456",
            statut=StatutCommande.EN_ATTENTE
        )

        # 1. Nouvelle mission
        FCMService.notifier_nouvelle_mission(self.livreur_user, commande)
        log1 = NotificationLog.objects.filter(user=self.livreur_user, data__type="NOUVELLE_MISSION").first()
        self.assertIsNotNone(log1)

        # 2. Mission annulée
        FCMService.notifier_mission_annulee(self.livreur_user, commande)
        log2 = NotificationLog.objects.filter(user=self.livreur_user, data__type="MISSION_ANNULEE").first()
        self.assertIsNotNone(log2)


class NotificationAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='user_api_test',
            telephone='+237699111222',
            role=UserRole.CLIENT
        )
        self.client.force_authenticate(user=self.user)

    def test_enregistrer_fcm_token_api(self):
        """Tester l'API POST /notifications/token/."""
        response = self.client.post('/notifications/token/', {
            "token": "token_api_valide_123456",
            "device_type": "android"
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(DeviceToken.objects.filter(token="token_api_valide_123456").exists())

    def test_mes_notifications_api(self):
        """Tester l'API GET /notifications/mes-notifications/."""
        NotificationLog.objects.create(
            user=self.user,
            titre="Test Notif API",
            corps="Corps de test",
            data={"key": "val"},
            statut="SIMULE"
        )
        response = self.client.get('/notifications/mes-notifications/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['titre'], "Test Notif API")
