from datetime import timedelta
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, UserRole


class AuthAPITests(APITestCase):
    def setUp(self):
        self.valid_phone = "+237677112233"
        self.password = "SecurePass123!"
        self.inscription_url = reverse('auth_inscription')
        self.verifier_otp_url = reverse('auth_verifier_otp')
        self.connexion_url = reverse('auth_connexion')
        self.refresh_url = reverse('auth_token_refresh')
        self.profil_url = reverse('auth_profil')

    def test_inscription_valid_phone_creates_user_with_otp(self):
        """L'inscription avec un numéro camerounais valide crée l'utilisateur et génère l'OTP."""
        data = {
            "telephone": "677112233",  # Sans indicatif au départ
            "password": self.password,
            "role": UserRole.CLIENT,
        }
        response = self.client.post(self.inscription_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["message"], "OTP envoyé")
        self.assertEqual(response.data["telephone"], "+237677112233")

        user = User.objects.get(telephone="+237677112233")
        self.assertFalse(user.is_verified)
        self.assertFalse(user.is_active)
        self.assertIsNotNone(user.otp_code)
        self.assertEqual(len(user.otp_code), 6)

    def test_inscription_invalid_phone_rejected(self):
        """L'inscription rejette un format de téléphone non conforme."""
        data = {
            "telephone": "0123456789",  # Format invalide
            "password": self.password,
            "role": UserRole.CLIENT,
        }
        response = self.client.post(self.inscription_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("telephone", response.data)

    def test_inscription_duplicate_verified_user_rejected(self):
        """Impossible de réinscrire un numéro déjà vérifié et actif."""
        User.objects.create_user(
            username="+237677112233",
            telephone="+237677112233",
            password=self.password,
            is_verified=True,
            is_active=True
        )
        data = {
            "telephone": "+237677112233",
            "password": "AnotherPassword",
            "role": UserRole.GERANT,
        }
        response = self.client.post(self.inscription_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_verifier_otp_success_activates_and_returns_tokens(self):
        """Une validation OTP correcte active le compte et retourne les jetons JWT."""
        user = User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            otp_code="123456",
            otp_created_at=timezone.now(),
            is_verified=False,
            is_active=False
        )
        data = {
            "telephone": self.valid_phone,
            "otp_code": "123456"
        }
        response = self.client.post(self.verifier_otp_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("tokens", response.data)
        self.assertIn("access", response.data["tokens"])
        self.assertIn("refresh", response.data["tokens"])

        user.refresh_from_db()
        self.assertTrue(user.is_verified)
        self.assertTrue(user.is_active)
        self.assertIsNone(user.otp_code)

    def test_verifier_otp_wrong_code_fails(self):
        """Un code OTP erroné est refusé."""
        User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            otp_code="123456",
            otp_created_at=timezone.now(),
            is_verified=False
        )
        data = {
            "telephone": self.valid_phone,
            "otp_code": "999999"
        }
        response = self.client.post(self.verifier_otp_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Code OTP incorrect", response.data["detail"])

    def test_verifier_otp_expired_fails(self):
        """Un code OTP généré il y a plus de 10 minutes est expiré."""
        User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            otp_code="123456",
            otp_created_at=timezone.now() - timedelta(minutes=11),
            is_verified=False
        )
        data = {
            "telephone": self.valid_phone,
            "otp_code": "123456"
        }
        response = self.client.post(self.verifier_otp_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("expiré", response.data["detail"])

    def test_connexion_unverified_user_forbidden(self):
        """Un compte non vérifié ne peut pas se connecter."""
        User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            is_verified=False,
            is_active=False
        )
        data = {
            "telephone": self.valid_phone,
            "password": self.password,
        }
        response = self.client.post(self.connexion_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_connexion_success_returns_jwt_tokens(self):
        """Une connexion avec bons identifiants retourne les jetons JWT 15min / 7j."""
        User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            is_verified=True,
            is_active=True,
            role=UserRole.GERANT
        )
        data = {
            "telephone": self.valid_phone,
            "password": self.password,
        }
        response = self.client.post(self.connexion_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data["tokens"])
        self.assertIn("refresh", response.data["tokens"])
        self.assertEqual(response.data["user"]["role"], UserRole.GERANT)

    def test_connexion_wrong_password_fails(self):
        """Mauvais mot de passe rejeté avec HTTP 401."""
        User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            is_verified=True,
            is_active=True
        )
        data = {
            "telephone": self.valid_phone,
            "password": "WrongPassword",
        }
        response = self.client.post(self.connexion_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_token_refresh_endpoint(self):
        """L'endpoint /auth/refresh/ délivre un nouveau token d'accès."""
        user = User.objects.create_user(
            username=self.valid_phone,
            telephone=self.valid_phone,
            password=self.password,
            is_verified=True,
            is_active=True
        )
        refresh = RefreshToken.for_user(user)
        response = self.client.post(self.refresh_url, {"refresh": str(refresh)}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)

    def test_profil_requires_authentication(self):
        """L'endpoint /auth/profil/ est protégé contre les requêtes anonymes."""
        response = self.client.get(self.profil_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_profil_get_and_update(self):
        """L'utilisateur authentifié peut consulter et mettre à jour son profil (FCM token, nom)."""
        user = User.objects.create_user(
            username="endie_yaounde",
            telephone=self.valid_phone,
            password=self.password,
            is_verified=True,
            is_active=True,
            role=UserRole.CLIENT,
            points_fidelite=50
        )
        self.client.force_authenticate(user=user)

        # GET profil
        response = self.client.get(self.profil_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["telephone"], self.valid_phone)
        self.assertEqual(response.data["points_fidelite"], 50)

        # PUT mise à jour FCM Token
        update_data = {
            "fcm_token": "fcm_test_token_yaounde_12345",
            "username": "dieudonne_eteme"
        }
        update_res = self.client.put(self.profil_url, update_data, format='json')
        self.assertEqual(update_res.status_code, status.HTTP_200_OK)
        self.assertEqual(update_res.data["fcm_token"], "fcm_test_token_yaounde_12345")
        self.assertEqual(update_res.data["username"], "dieudonne_eteme")
