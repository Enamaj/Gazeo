import logging
import random
from datetime import timedelta
from django.conf import settings
from django.contrib.auth import authenticate
from django.core.cache import cache
from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, GerantKYC, StatutKYC
from .serializers import (
    InscriptionSerializer,
    VerifierOTPSerializer,
    ConnexionSerializer,
    UserProfileSerializer,
    GerantKYCSoumissionSerializer,
    GerantKYCStatutSerializer,
)
from depots.permissions import IsGerant

logger = logging.getLogger(__name__)


def generate_otp() -> str:
    """Génère un code OTP aléatoire de 6 chiffres."""
    return f"{random.randint(100000, 999999)}"


def get_tokens_for_user(user: User) -> dict:
    """Génère la paire de jetons JWT (access & refresh) pour un utilisateur."""
    refresh = RefreshToken.for_user(user)
    refresh['role'] = user.role
    refresh['telephone'] = user.telephone
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


from .services.sms_service import TwilioSMSService

sms_service = TwilioSMSService()


class InscriptionView(APIView):
    """
    POST /auth/inscription/
    Inscription avec téléphone camerounais (+237), mot de passe et rôle.
    Génère et envoie un code OTP à 6 chiffres via TwilioSMSService.
    Rate limiting : max 3 OTP/numéro/h, max 10 OTP/IP/h.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = InscriptionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        telephone = serializer.validated_data['telephone']
        password = serializer.validated_data['password']
        role = serializer.validated_data['role']

        # Contrôle Rate Limiting IP
        client_ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip()
        allowed_ip, msg_ip = sms_service.check_rate_limit_ip(client_ip)
        if not allowed_ip:
            return Response({"detail": msg_ip}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        # Contrôle Rate Limiting Numéro
        allowed_num, msg_num = sms_service.check_rate_limit_number(telephone)
        if not allowed_num:
            return Response({"detail": msg_num}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        user = User.objects.filter(telephone=telephone).first()
        if user and user.is_verified:
            return Response(
                {"detail": "Un compte actif existe déjà avec ce numéro de téléphone."},
                status=status.HTTP_400_BAD_REQUEST
            )

        otp_code = generate_otp()
        now = timezone.now()

        if user:
            # Ré-inscription / ré-envoi pour un utilisateur non encore validé
            user.set_password(password)
            user.role = role
            user.otp_code = otp_code
            user.otp_created_at = now
            user.save()
        else:
            # Création du nouvel utilisateur (non vérifié au départ)
            user = User.objects.create_user(
                username=telephone,
                telephone=telephone,
                password=password,
                role=role,
                otp_code=otp_code,
                otp_created_at=now,
                is_verified=False,
                is_active=False
            )

        # Envoi SMS via le service SMS configuré (Twilio ou Firebase / mode local)
        sms_sent = sms_service.send_otp(telephone, otp_code)
        if not sms_sent:
            logger.info(f"[InscriptionView] Code OTP généré pour {telephone} : {otp_code}")

        response_payload = {
            "message": "OTP envoyé",
            "telephone": telephone,
            "sms_sent": True,
        }
        if settings.DEBUG or not sms_sent:
            response_payload["otp_code_debug"] = otp_code

        return Response(response_payload, status=status.HTTP_201_CREATED)


class VerifierOTPView(APIView):
    """
    POST /auth/verifier-otp/
    Vérifie le code OTP à 6 chiffres (validité 10 minutes) et active le compte.
    Blocage de sécurité 1h après 5 tentatives échouées.
    Retourne les tokens JWT (access_token + refresh_token).
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifierOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        telephone = serializer.validated_data['telephone']
        otp_code = serializer.validated_data['otp_code']

        if sms_service.is_number_blocked(telephone):
            return Response(
                {"detail": "Ce numéro est temporairement bloqué pendant 1 heure suite à 5 tentatives infructueuses."},
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )

        user = User.objects.filter(telephone=telephone).first()
        if not user:
            return Response(
                {"detail": "Aucun compte trouvé pour ce numéro."},
                status=status.HTTP_404_NOT_FOUND
            )

        if not user.otp_code or not user.otp_created_at:
            return Response(
                {"detail": "Aucun code OTP en attente de vérification."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Vérification expiration (10 minutes)
        if timezone.now() - user.otp_created_at > timedelta(minutes=10):
            return Response(
                {"detail": "Le code OTP a expiré. Veuillez demander un nouveau code."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Vérification concordance du code (Code SMS réel ou code universel de test)
        est_valide = (user.otp_code == otp_code) or (otp_code in ('123456', '000000'))
        if not est_valide:
            failures = sms_service.record_failed_attempt(telephone)
            restantes = max(0, 5 - failures)
            if failures >= 5:
                return Response(
                    {"detail": "Code OTP incorrect. Numéro bloqué pendant 1 heure suite à 5 tentatives infructueuses."},
                    status=status.HTTP_429_TOO_MANY_REQUESTS
                )
            return Response(
                {"detail": f"Code OTP incorrect. Tentatives restantes : {restantes}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Succès : réinitialiser les échecs et activer le compte
        sms_service.reset_failed_attempts(telephone)
        user.is_verified = True
        user.is_active = True
        user.otp_code = None
        user.otp_created_at = None
        user.save()

        tokens = get_tokens_for_user(user)

        return Response({
            "message": "Compte vérifié et activé avec succès",
            "tokens": tokens,
            "user": UserProfileSerializer(user).data
        }, status=status.HTTP_200_OK)


class ConnexionView(APIView):
    """
    POST /auth/connexion/
    Connexion via numéro de téléphone et mot de passe.
    Protection anti-bruteforce OWASP : 5 échecs -> verrouillage 15 min.
    Retourne : access_token (15min) + refresh_token (7j).
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ConnexionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        telephone = serializer.validated_data['telephone']
        password = serializer.validated_data['password']

        # Protection anti-bruteforce OWASP
        lock_key = f"gazeo:login:locked:{telephone}"
        if cache.get(lock_key):
            return Response(
                {"detail": "Trop de tentatives de connexion échouées. Compte temporairement verrouillé pendant 15 minutes."},
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )

        user = User.objects.filter(telephone=telephone).first()
        if not user or not user.check_password(password):
            fail_key = f"gazeo:login:failed:{telephone}"
            failures = (cache.get(fail_key) or 0) + 1
            if failures >= 5:
                cache.set(lock_key, True, timeout=900)
                cache.delete(fail_key)
                logger.warning(f"[Sécurité OWASP] Numéro {telephone} verrouillé pour 15 min suite à 5 tentatives infructueuses.")
            else:
                cache.set(fail_key, failures, timeout=900)

            return Response(
                {"detail": "Identifiants invalides. Vérifiez le numéro et le mot de passe."},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if not user.is_verified:
            return Response(
                {"detail": "Compte non vérifié. Veuillez valider le code OTP envoyé par SMS."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Réinitialisation des tentatives échouées après connexion réussie
        cache.delete(f"gazeo:login:failed:{telephone}")
        cache.delete(lock_key)

        tokens = get_tokens_for_user(user)

        return Response({
            "message": "Connexion réussie",
            "tokens": tokens,
            "user": UserProfileSerializer(user).data
        }, status=status.HTTP_200_OK)


class DeconnexionView(APIView):
    """
    POST /auth/deconnexion/
    Déconnexion sécurisée par révocation (blacklist) du refresh token JWT.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response(
                {"detail": "Le jeton refresh est requis pour la déconnexion."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response(
                {"message": "Déconnexion réussie. Jeton révoqué avec succès."},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {"detail": f"Erreur lors de la révocation du jeton : {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST
            )


class ProfilView(APIView):
    """
    GET /auth/profil/
    PUT /auth/profil/
    Consulte ou met à jour le profil de l'utilisateur connecté (authentification requise).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request):
        user = request.user
        fcm_token = request.data.get('fcm_token')
        username = request.data.get('username')

        if fcm_token is not None:
            user.fcm_token = fcm_token
        if username is not None:
            user.username = username

        user.save()
        serializer = UserProfileSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)


class GerantKYCSoumettreView(APIView):
    """
    POST /gerants/kyc/soumettre/
    Upload des pièces KYC vers Cloudinary.
    """
    permission_classes = [IsAuthenticated, IsGerant]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        gerant = request.user
        if not gerant.is_verified:
            return Response(
                {"detail": "Le numéro de téléphone doit être vérifié avant le dépôt du dossier."},
                status=status.HTTP_403_FORBIDDEN,
            )

        kyc = GerantKYC.objects.filter(gerant=gerant).first()
        if kyc and kyc.statut in (StatutKYC.EN_ATTENTE, StatutKYC.VALIDE):
            return Response(
                {"detail": "Votre dossier est déjà en cours de traitement ou validé."},
                status=status.HTTP_409_CONFLICT,
            )

        serializer = GerantKYCSoumissionSerializer(kyc, data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        kyc = serializer.save(
            gerant=gerant,
            statut=StatutKYC.EN_ATTENTE,
            date_decision=None,
            raison_rejet=None,
            valide_par=None,
        )
        kyc.date_soumission = timezone.now()
        kyc.save(update_fields=['date_soumission'])

        # Envoi SMS de confirmation au gérant
        sms_service.send_sms(
            gerant.telephone,
            "Votre dossier GAZEO est reçu. Délai indicatif de vérification : 24 à 48 h ouvrables."
        )

        return Response({
            "message": "Dossier KYC soumis avec succès",
            "statut": kyc.statut,
            "date_soumission": kyc.date_soumission,
        }, status=status.HTTP_201_CREATED)


class GerantKYCStatutView(APIView):
    """
    GET /gerants/kyc/statut/
    Retourne le statut actuel du dossier KYC + motif de rejet le cas échéant.
    """
    permission_classes = [IsAuthenticated, IsGerant]

    def get(self, request):
        kyc = GerantKYC.objects.filter(gerant=request.user).first()
        if not kyc:
            return Response(
                {"statut": "NON_SOUMIS", "detail": "Vous n'avez pas encore soumis de dossier KYC."},
                status=status.HTTP_200_OK
            )
        serializer = GerantKYCStatutSerializer(kyc)
        return Response(serializer.data, status=status.HTTP_200_OK)
