from datetime import timedelta
from io import BytesIO
from unittest.mock import patch

from cloudinary import CloudinaryResource
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
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

    def _image_upload(self, name):
        buffer = BytesIO()
        Image.new('RGB', (2, 2), color='white').save(buffer, format='PNG')
        return SimpleUploadedFile(
            name,
            buffer.getvalue(),
            content_type='image/png',
        )

    def test_inscription_valid_phone_creates_user_with_otp(self):
        """L'inscription avec un numéro camerounais valide crée l'utilisateur et génère l'OTP."""
        data = {
            "telephone": "677112233",  # Sans indicatif au départ
            "password": self.password,
            "role": UserRole.CLIENT,
        }
        with patch('auth_user.views.sms_service.send_otp', return_value=True):
            response = self.client.post(self.inscription_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["message"], "OTP envoyé")
        self.assertTrue(response.data["sms_sent"])
        self.assertEqual(response.data["telephone"], "+237677112233")

        user = User.objects.get(telephone="+237677112233")
        self.assertFalse(user.is_verified)
        self.assertFalse(user.is_active)
        self.assertIsNotNone(user.otp_code)
        self.assertEqual(len(user.otp_code), 6)

    @override_settings(DEBUG=False)
    @patch('auth_user.views.sms_service.send_otp', return_value=False)
    def test_inscription_sms_failure_is_reported_outside_debug(self, _send_otp):
        response = self.client.post(
            self.inscription_url,
            {
                "telephone": "+237677112234",
                "password": self.password,
                "role": UserRole.CLIENT,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertIn("n'a pas pu être envoyé", response.data["detail"])
        self.assertNotIn("otp_code_debug", response.data)

    @override_settings(DEBUG=True)
    @patch('auth_user.views.sms_service.send_otp', return_value=False)
    def test_inscription_debug_exposes_code_only_when_sms_is_not_sent(self, _send_otp):
        response = self.client.post(
            self.inscription_url,
            {
                "telephone": "+237677112235",
                "password": self.password,
                "role": UserRole.CLIENT,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(response.data["sms_sent"])
        self.assertIn("Mode développement", response.data["message"])
        self.assertEqual(
            response.data["otp_code_debug"],
            User.objects.get(telephone="+237677112235").otp_code,
        )

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

    def test_twilio_cameroon_phone_validation(self):
        """TwilioSMSService valide et normalise les numéros camerounais."""
        from auth_user.services.sms_service import TwilioSMSService
        service = TwilioSMSService()

        self.assertEqual(service.validate_cameroon_number("677112233"), "+237677112233")
        self.assertEqual(service.validate_cameroon_number("+237699001122"), "+237699001122")
        self.assertEqual(service.validate_cameroon_number("237 6 55 44 33 22"), "+237655443322")

        with self.assertRaises(ValueError):
            service.validate_cameroon_number("0612345678")
        with self.assertRaises(ValueError):
            service.validate_cameroon_number("1234")

    def test_twilio_rate_limiting_and_lockout(self):
        """Rate limiting : max 3 OTP par numéro et blocage après 5 échecs consécutifs."""
        from auth_user.services.sms_service import TwilioSMSService
        service = TwilioSMSService()
        test_phone = "+237699887766"

        # 3 premières tentatives autorisées
        self.assertTrue(service.check_rate_limit_number(test_phone)[0])
        self.assertTrue(service.check_rate_limit_number(test_phone)[0])
        self.assertTrue(service.check_rate_limit_number(test_phone)[0])

        # 4ème tentative refusée par rate limit
        allowed, msg = service.check_rate_limit_number(test_phone)
        self.assertFalse(allowed)
        self.assertIn("maximum 3 codes", msg)

        # Enregistrement de 5 échecs -> blocage
        for _ in range(5):
            service.record_failed_attempt(test_phone)

        self.assertTrue(service.is_number_blocked(test_phone))
        # Reset des échecs
        service.reset_failed_attempts(test_phone)
        self.assertFalse(service.is_number_blocked(test_phone))

    def test_gerant_kyc_workflow(self):
        """Workflow KYC : soumission par le gérant et consultation du statut."""
        gerant = User.objects.create_user(
            username="+237688990011",
            telephone="+237688990011",
            password=self.password,
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True
        )
        self.client.force_authenticate(user=gerant)

        # GET statut avant soumission
        statut_url = reverse('gerants:gerant_kyc_statut')
        res_statut = self.client.get(statut_url)
        self.assertEqual(res_statut.status_code, status.HTTP_200_OK)
        self.assertEqual(res_statut.data['statut'], 'NON_SOUMIS')

        # POST soumission KYC
        soumettre_url = reverse('gerants:gerant_kyc_soumettre')
        data = {
            "cni_recto": self._image_upload('cni_recto.png'),
            "cni_verso": self._image_upload('cni_verso.png'),
            "photo_depot": self._image_upload('depot_facade.png'),
            "photo_depot_interieur": self._image_upload('depot_interieur.png'),
            "document_commercial": SimpleUploadedFile(
                'registre.pdf',
                b'%PDF-1.4\nTest document',
                content_type='application/pdf',
            ),
        }

        def fake_cloudinary_upload(_file, **options):
            return CloudinaryResource(
                public_id=f"test/kyc_{options['resource_type']}",
                format='pdf' if options['resource_type'] == 'raw' else 'png',
                version='1',
                type=options['type'],
                resource_type=options['resource_type'],
            )

        with patch(
            'cloudinary.models.uploader.upload_resource',
            side_effect=fake_cloudinary_upload,
        ) as cloudinary_upload:
            res_soumission = self.client.post(
                soumettre_url,
                data,
                format='multipart',
            )
        self.assertEqual(cloudinary_upload.call_count, 5)
        self.assertTrue(
            all(
                call.kwargs['type'] == 'authenticated'
                for call in cloudinary_upload.call_args_list
            )
        )
        self.assertEqual(res_soumission.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_soumission.data['statut'], 'EN_ATTENTE')

        # GET statut après soumission
        res_statut_apres = self.client.get(statut_url)
        self.assertEqual(res_statut_apres.status_code, status.HTTP_200_OK)
        self.assertEqual(res_statut_apres.data['statut'], 'EN_ATTENTE')
        self.assertNotIn('cni_recto', res_statut_apres.data)
        self.assertNotIn('document_commercial', res_statut_apres.data)

        # A pending application cannot be silently replaced.
        res_soumission_dupliquee = self.client.post(soumettre_url, {}, format='multipart')
        self.assertEqual(
            res_soumission_dupliquee.status_code,
            status.HTTP_409_CONFLICT,
        )

    def test_gerant_kyc_requires_all_documents(self):
        gerant = User.objects.create_user(
            username="+237688990012",
            telephone="+237688990012",
            password="SecurePass123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True,
        )
        self.client.force_authenticate(user=gerant)
        response = self.client.post(
            reverse('gerants:gerant_kyc_soumettre'),
            {"cni_recto": "https://res.cloudinary.com/test/image/upload/cni.jpg"},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('cni_verso', response.data)
        self.assertIn('photo_depot', response.data)
        self.assertIn('photo_depot_interieur', response.data)
        self.assertIn('document_commercial', response.data)

    def test_gerant_kyc_rejects_document_urls(self):
        gerant = User.objects.create_user(
            username="+237688990014",
            telephone="+237688990014",
            password="SecurePass123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True,
        )
        self.client.force_authenticate(user=gerant)
        response = self.client.post(
            reverse('gerants:gerant_kyc_soumettre'),
            {
                field: "https://res.cloudinary.com/test/image/upload/document.jpg"
                for field in (
                    'cni_recto',
                    'cni_verso',
                    'photo_depot',
                    'photo_depot_interieur',
                    'document_commercial',
                )
            },
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        for field in (
            'cni_recto',
            'cni_verso',
            'photo_depot',
            'photo_depot_interieur',
            'document_commercial',
        ):
            self.assertIn(field, response.data)

    def test_gerant_kyc_requires_verified_phone(self):
        gerant = User.objects.create_user(
            username="+237688990013",
            telephone="+237688990013",
            password="SecurePass123!",
            role=UserRole.GERANT,
            is_verified=False,
            is_active=True,
        )
        self.client.force_authenticate(user=gerant)
        response = self.client.post(
            reverse('gerants:gerant_kyc_soumettre'),
            {},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("vérifié", response.data['detail'])

    def test_connexion_anti_bruteforce_lockout(self):
        """Protection anti-bruteforce : verrouillage après 5 échecs consécutifs."""
        from django.core.cache import cache
        cache.clear()

        user = User.objects.create_user(
            username="+237699112233",
            telephone="+237699112233",
            password="GoodPassword123!",
            role=UserRole.CLIENT,
            is_verified=True,
            is_active=True
        )

        connexion_url = reverse('auth_connexion')
        bad_payload = {"telephone": "+237699112233", "password": "WrongPassword!"}

        # 5 tentatives infructueuses
        for _ in range(5):
            res = self.client.post(connexion_url, bad_payload, format='json')
            self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

        # 6ème tentative : compte temporairement verrouillé (HTTP 429)
        res_locked = self.client.post(connexion_url, bad_payload, format='json')
        self.assertEqual(res_locked.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("temporairement verrouillé", res_locked.data['detail'])

    def test_deconnexion_token_blacklisting(self):
        """Déconnexion sécurisée : révocation (blacklist) du refresh token JWT."""
        user = User.objects.create_user(
            username="+237699223344",
            telephone="+237699223344",
            password="StrongPassword123!",
            role=UserRole.CLIENT,
            is_verified=True,
            is_active=True
        )

        # Connexion pour obtenir les tokens
        connexion_url = reverse('auth_connexion')
        res_login = self.client.post(connexion_url, {
            "telephone": "+237699223344",
            "password": "StrongPassword123!"
        }, format='json')
        self.assertEqual(res_login.status_code, status.HTTP_200_OK)
        refresh_token = res_login.data['tokens']['refresh']
        access_token = res_login.data['tokens']['access']

        # Déconnexion avec blacklist du refresh token
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        deconnexion_url = reverse('auth_deconnexion')
        res_logout = self.client.post(deconnexion_url, {"refresh": refresh_token}, format='json')
        self.assertEqual(res_logout.status_code, status.HTTP_200_OK)
        self.assertIn("Jeton révoqué avec succès", res_logout.data['message'])

        # Vérifier que le refresh token révoqué ne peut plus être utilisé pour refresh
        refresh_url = reverse('auth_token_refresh')
        res_refresh = self.client.post(refresh_url, {"refresh": refresh_token}, format='json')
        self.assertEqual(res_refresh.status_code, status.HTTP_401_UNAUTHORIZED)
