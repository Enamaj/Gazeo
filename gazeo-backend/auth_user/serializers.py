import re
from pathlib import Path

from django.core.files.uploadedfile import UploadedFile
from PIL import Image, UnidentifiedImageError
from rest_framework import serializers
from .models import User, UserRole, GerantKYC, StatutKYC


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


class GerantKYCSoumissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = GerantKYC
        fields = (
            'cni_recto',
            'cni_verso',
            'photo_depot',
            'photo_depot_interieur',
            'document_commercial',
        )

    def validate(self, attrs):
        missing = [
            field
            for field in self.Meta.fields
            if not attrs.get(field) and not getattr(self.instance, field, None)
        ]
        if missing:
            labels = {
                'cni_recto': 'CNI recto',
                'cni_verso': 'CNI verso',
                'photo_depot': 'photo de façade du dépôt',
                'photo_depot_interieur': 'photo intérieure du dépôt',
                'document_commercial': 'registre de commerce ou attestation d’activité',
            }
            raise serializers.ValidationError({
                field: f"Le document « {labels[field]} » est obligatoire."
                for field in missing
            })

        allowed_extensions = {
            'cni_recto': {'jpg', 'jpeg', 'png'},
            'cni_verso': {'jpg', 'jpeg', 'png'},
            'photo_depot': {'jpg', 'jpeg', 'png'},
            'photo_depot_interieur': {'jpg', 'jpeg', 'png'},
            'document_commercial': {'pdf', 'jpg', 'jpeg', 'png'},
        }
        errors = {}
        for field, extensions in allowed_extensions.items():
            uploaded_file = attrs.get(field)
            if not isinstance(uploaded_file, UploadedFile):
                errors[field] = "Veuillez joindre le fichier original, pas un lien."
                continue
            extension = Path(uploaded_file.name).suffix.lower().lstrip('.')
            if extension not in extensions:
                errors[field] = (
                    f"Format non accepté. Extensions autorisées : "
                    f"{', '.join(sorted(extensions))}."
                )
                continue
            if uploaded_file.size > 10 * 1024 * 1024:
                errors[field] = "La taille maximale autorisée est de 10 Mo."
                continue
            uploaded_file.seek(0)
            if field == 'document_commercial' and extension == 'pdf':
                if uploaded_file.read(5) != b'%PDF-':
                    errors[field] = "Le fichier n’est pas un PDF valide."
            else:
                try:
                    with Image.open(uploaded_file) as image:
                        image.verify()
                except (
                    Image.DecompressionBombError,
                    UnidentifiedImageError,
                    OSError,
                ):
                    errors[field] = "Le fichier image est invalide ou illisible."
            uploaded_file.seek(0)
        if errors:
            raise serializers.ValidationError(errors)
        return attrs


class GerantKYCStatutSerializer(serializers.ModelSerializer):
    gerant_telephone = serializers.CharField(source='gerant.telephone', read_only=True)

    class Meta:
        model = GerantKYC
        fields = (
            'id',
            'gerant_telephone',
            'statut',
            'raison_rejet',
            'date_soumission',
            'date_decision',
        )
