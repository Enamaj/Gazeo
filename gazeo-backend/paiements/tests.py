import hashlib
import hmac
import json
from decimal import Decimal
from django.conf import settings
from django.contrib.gis.geos import Point
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from auth_user.models import User, UserRole
from depots.models import Depot, MarqueGaz, StatutKYC
from commandes.models import Commande, StatutCommande
from paiements.models import Paiement, StatutPaiement, VirementHebdomadaire


class PaiementsAPITests(APITestCase):
    def setUp(self):
        self.client_user = User.objects.create_user(
            username="+237699112233",
            telephone="+237699112233",
            password="Password123!",
            role=UserRole.CLIENT,
            is_verified=True,
            is_active=True
        )
        self.autre_client = User.objects.create_user(
            username="+237688223344",
            telephone="+237688223344",
            password="Password123!",
            role=UserRole.CLIENT,
            is_verified=True,
            is_active=True
        )
        self.gerant_user = User.objects.create_user(
            username="+237677334455",
            telephone="+237677334455",
            password="Password123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True
        )
        self.admin_user = User.objects.create_user(
            username="+237655001122",
            telephone="+237655001122",
            password="Password123!",
            role=UserRole.ADMIN,
            is_verified=True,
            is_active=True,
            is_staff=True
        )

        self.depot = Depot.objects.create(
            nom="Dépôt Tradex Bastos",
            adresse="Avenue Bastos",
            quartier="Bastos",
            telephone="+237677334455",
            localisation=Point(11.5180, 3.8850, srid=4326),
            gerant=self.gerant_user,
            marque=MarqueGaz.TRADEX,
            stock_6kg=10,
            stock_12kg=20,
            prix_6kg=Decimal('3000.00'),
            prix_12kg=Decimal('6500.00'),
            statut_kyc=StatutKYC.VALIDE,
            est_actif=True
        )

        self.commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            quantite_6kg=1,
            quantite_12kg=1,
            montant_total=Decimal('10500.00'),
            frais_livraison=Decimal('1000.00'),
            statut=StatutCommande.EN_ATTENTE,
            adresse_livraison="Bastos Rue 12",
            latitude_livraison=3.8870,
            longitude_livraison=11.5190,
            code_confirmation="123456"
        )

        # Clé secrète de test pour signature HMAC
        self.secret_hash = "notchpay_secret_hash_test_123456"
        settings.NOTCHPAY_HASH = self.secret_hash

    def _generate_signature(self, payload_dict: dict) -> tuple[bytes, str]:
        body_bytes = json.dumps(payload_dict).encode('utf-8')
        signature = hmac.new(
            key=self.secret_hash.encode('utf-8'),
            msg=body_bytes,
            digestmod=hashlib.sha256
        ).hexdigest()
        return body_bytes, signature

    def test_initier_paiement_success(self):
        """Initialisation de paiement Notchpay en sandbox."""
        self.client.force_authenticate(user=self.client_user)
        url = reverse('paiement_initier')
        data = {"commande_id": self.commande.id}

        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("authorization_url", response.data)
        self.assertIn("reference", response.data)

        # Vérification création enregistrement Paiement
        paiement = Paiement.objects.get(commande=self.commande)
        self.assertEqual(paiement.statut, StatutPaiement.PENDING)
        self.assertEqual(paiement.montant, Decimal('10500.00'))

    def test_initier_paiement_forbidden_for_other_user(self):
        """Un autre client ne peut pas payer la commande de quelqu'un d'autre."""
        self.client.force_authenticate(user=self.autre_client)
        url = reverse('paiement_initier')
        response = self.client.post(url, {"commande_id": self.commande.id}, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_webhook_notchpay_complete_and_commission_calculation(self):
        """Webhook avec signature HMAC valide -> Paiement SUCCESS et commission GAZEO de 1,5%."""
        paiement = Paiement.objects.create(
            commande=self.commande,
            reference_notchpay=f"GAZEO-CMD-{self.commande.id}",
            montant=Decimal('10000.00'),
            statut=StatutPaiement.PENDING
        )

        webhook_url = reverse('notchpay_webhook')
        payload = {
            "event": "payment.complete",
            "data": {
                "reference": paiement.reference_notchpay,
                "status": "complete",
                "amount": 10000,
            }
        }
        body_bytes, sig = self._generate_signature(payload)

        # Appel public webhook sans auth mais avec header x-notch-signature
        response = self.client.post(
            webhook_url,
            data=body_bytes,
            content_type='application/json',
            HTTP_X_NOTCH_SIGNATURE=sig
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        paiement.refresh_from_db()
        self.assertEqual(paiement.statut, StatutPaiement.SUCCESS)

        # Commission 1,5% sur 10 000 FCFA = 150 FCFA, net = 9 850 FCFA
        self.assertEqual(paiement.commission_gazeo, Decimal('150.00'))
        self.assertEqual(paiement.montant_net_gerant, Decimal('9850.00'))

    def test_webhook_notchpay_idempotence(self):
        """Idempotence : un second appel webhook pour la même référence est ignoré sans erreur."""
        paiement = Paiement.objects.create(
            commande=self.commande,
            reference_notchpay="REF-IDEMPOTENT-123",
            montant=Decimal('10000.00'),
            statut=StatutPaiement.SUCCESS,
            commission_gazeo=Decimal('150.00'),
            montant_net_gerant=Decimal('9850.00')
        )

        webhook_url = reverse('notchpay_webhook')
        payload = {
            "event": "payment.complete",
            "data": {
                "reference": "REF-IDEMPOTENT-123",
                "status": "complete",
            }
        }
        body_bytes, sig = self._generate_signature(payload)

        response = self.client.post(
            webhook_url,
            data=body_bytes,
            content_type='application/json',
            HTTP_X_NOTCH_SIGNATURE=sig
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'already_processed')

    def test_webhook_notchpay_invalid_hmac_rejected(self):
        """Rejet immédiat d'un webhook avec signature HMAC non conforme."""
        webhook_url = reverse('notchpay_webhook')
        payload = {"data": {"reference": "FAKE-REF", "status": "complete"}}
        body_bytes, _ = self._generate_signature(payload)

        response = self.client.post(
            webhook_url,
            data=body_bytes,
            content_type='application/json',
            HTTP_X_NOTCH_SIGNATURE="mauvaise_signature_frelatee"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_rembourser_paiement_admin_only(self):
        """Remboursement réservé aux administrateurs."""
        paiement = Paiement.objects.create(
            commande=self.commande,
            reference_notchpay="REF-REFUND-123",
            montant=Decimal('5000.00'),
            statut=StatutPaiement.SUCCESS
        )
        url = reverse('paiement_rembourser', kwargs={'pk': paiement.pk})

        # Client standard -> 403
        self.client.force_authenticate(user=self.client_user)
        res_client = self.client.post(url, {"motif": "Client insatisfait"}, format='json')
        self.assertEqual(res_client.status_code, status.HTTP_403_FORBIDDEN)

        # Admin -> 200 OK
        self.client.force_authenticate(user=self.admin_user)
        res_admin = self.client.post(url, {"motif": "Annulation légitime"}, format='json')
        self.assertEqual(res_admin.status_code, status.HTTP_200_OK)

        paiement.refresh_from_db()
        self.assertEqual(paiement.statut, StatutPaiement.REFUNDED)
        self.assertEqual(paiement.rembourse_par, self.admin_user)
        self.assertIsNotNone(paiement.rembourse_at)

    def test_calculer_virements_hebdomadaires(self):
        """Calcul automatisé des virements hebdomadaires avec commission 1,5%."""
        self.commande.statut = StatutCommande.LIVREE
        self.commande.save()

        url = reverse('virements_calcul')
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['taux_commission'], '1.5%')
        self.assertGreater(response.data['nombre_gerants'], 0)
