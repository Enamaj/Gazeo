import re
from rest_framework import serializers
from .models import User, UserRole


def normalize_cameroon_phone(phone: str) -> str:
    """
    Normalise et valide un numéro de téléphone camerounais au format +2376XXXXXXXX.
    Accepte : +2376XXXXXXXX, 2376XXXXXXXX, 6XXXXXXXX, ou avec espaces/tirets.
    """
    cleaned = re.sub(r'[\s\-\(\)]', '', phone)
    match = re.match(r'^(?:\+?237)?(6[25789]\d{7}|6\d{8})$', cleaned)
    if not match:
        raise serializers.ValidationError(
            "Numéro de téléphone camerounais invalide. Format attendu : (+237) 6XX XX XX XX."
        )
    number_body = match.group(1)
    return f"+237{number_body}"


class InscriptionSerializer(serializers.Serializer):
    telephone = serializers.CharField(max_length=25)
    password = serializers.CharField(write_only=True, min_length=6)
    role = serializers.ChoiceField(choices=UserRole.choices, default=UserRole.CLIENT)

    def validate_telephone(self, value):
        return normalize_cameroon_phone(value)


class VerifierOTPSerializer(serializers.Serializer):
    telephone = serializers.CharField(max_length=25)
    otp_code = serializers.CharField(max_length=6, min_length=6)

    def validate_telephone(self, value):
        return normalize_cameroon_phone(value)


class ConnexionSerializer(serializers.Serializer):
    telephone = serializers.CharField(max_length=25)
    password = serializers.CharField(write_only=True)

    def validate_telephone(self, value):
        return normalize_cameroon_phone(value)


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'id',
            'telephone',
            'username',
            'role',
            'fcm_token',
            'points_fidelite',
            'is_verified',
            'date_joined',
        )
        read_only_fields = ('id', 'telephone', 'role', 'points_fidelite', 'is_verified', 'date_joined')

