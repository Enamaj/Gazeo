import logging
import random
from datetime import timedelta
from django.conf import settings
from django.contrib.auth import authenticate
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User
from .serializers import (
    InscriptionSerializer,
    VerifierOTPSerializer,
    ConnexionSerializer,
    UserProfileSerializer,
)

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


class InscriptionView(APIView):
    """
    POST /auth/inscription/
    Inscription avec téléphone camerounais (+237), mot de passe et rôle.
    Génère et envoie un code OTP à 6 chiffres.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = InscriptionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        telephone = serializer.validated_data['telephone']
        password = serializer.validated_data['password']
        role = serializer.validated_data['role']

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

        # Simulation / Envoi SMS (Twilio intégré en phase 3)
        logger.info(f"[GAZEO OTP] Code généré pour {telephone} : {otp_code}")

        response_payload = {
            "message": "OTP envoyé",
            "telephone": telephone,
        }
        # En mode DEBUG ou tests, exposer le code OTP pour faciliter le test automatisé
        if settings.DEBUG:
            response_payload["otp_code_debug"] = otp_code

        return Response(response_payload, status=status.HTTP_201_CREATED)


class VerifierOTPView(APIView):
    """
    POST /auth/verifier-otp/
    Vérifie le code OTP à 6 chiffres (validité 10 minutes) et active le compte.
    Retourne les tokens JWT (access_token + refresh_token).
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifierOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        telephone = serializer.validated_data['telephone']
        otp_code = serializer.validated_data['otp_code']

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

        # Vérification concordance du code
        if user.otp_code != otp_code:
            return Response(
                {"detail": "Code OTP incorrect."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Activation du compte
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
    Retourne : access_token (15min) + refresh_token (7j).
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ConnexionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        telephone = serializer.validated_data['telephone']
        password = serializer.validated_data['password']

        user = User.objects.filter(telephone=telephone).first()
        if not user or not user.check_password(password):
            return Response(
                {"detail": "Identifiants invalides. Vérifiez le numéro et le mot de passe."},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if not user.is_verified:
            return Response(
                {"detail": "Compte non vérifié. Veuillez valider le code OTP envoyé par SMS."},
                status=status.HTTP_403_FORBIDDEN
            )

        tokens = get_tokens_for_user(user)

        return Response({
            "message": "Connexion réussie",
            "tokens": tokens,
            "user": UserProfileSerializer(user).data
        }, status=status.HTTP_200_OK)


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
