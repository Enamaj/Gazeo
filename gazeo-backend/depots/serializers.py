from django.contrib.gis.geos import Point
from rest_framework import serializers
from .models import Depot, MarqueGaz, StatutKYC
from notation.models import Avis


class AvisPublicSerializer(serializers.ModelSerializer):
    client_telephone = serializers.SerializerMethodField()

    class Meta:
        model = Avis
        fields = ('id', 'client_telephone', 'note', 'commentaire', 'created_at')

    def get_client_telephone(self, obj):
        # Masquer une partie du numéro pour la confidentialité (ex: +237 6** ** 33)
        tel = obj.client.telephone
        if len(tel) >= 9:
            return f"{tel[:6]}****{tel[-2:]}"
        return tel


class DepotProcheSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField(read_only=True)
    longitude = serializers.FloatField(read_only=True)
    stock_disponible = serializers.IntegerField(read_only=True)
    distance_metres = serializers.SerializerMethodField()
    distance_km = serializers.SerializerMethodField()
    note_moyenne = serializers.SerializerMethodField()

    class Meta:
        model = Depot
        fields = (
            'id',
            'nom',
            'adresse',
            'quartier',
            'telephone',
            'marque',
            'stock_6kg',
            'stock_12kg',
            'stock_disponible',
            'prix_6kg',
            'prix_12kg',
            'latitude',
            'longitude',
            'distance_metres',
            'distance_km',
            'note_moyenne',
            'statut_kyc',
            'est_actif',
        )

    def get_distance_metres(self, obj) -> float | None:
        if hasattr(obj, 'distance') and obj.distance is not None:
            return round(obj.distance.m, 1)
        return None

    def get_distance_km(self, obj) -> float | None:
        if hasattr(obj, 'distance') and obj.distance is not None:
            return round(obj.distance.km, 2)
        return None

    def get_note_moyenne(self, obj) -> float | None:
        avis = obj.avis.all()
        if avis.exists():
            return round(sum(a.note for a in avis) / avis.count(), 1)
        return 5.0  # Note par défaut de démarrage


class DepotDetailSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField(read_only=True)
    longitude = serializers.FloatField(read_only=True)
    stock_disponible = serializers.IntegerField(read_only=True)
    note_moyenne = serializers.SerializerMethodField()
    total_avis = serializers.SerializerMethodField()
    derniers_avis = serializers.SerializerMethodField()

    class Meta:
        model = Depot
        fields = (
            'id',
            'nom',
            'adresse',
            'quartier',
            'telephone',
            'marque',
            'stock_6kg',
            'stock_12kg',
            'stock_disponible',
            'prix_6kg',
            'prix_12kg',
            'latitude',
            'longitude',
            'note_moyenne',
            'total_avis',
            'derniers_avis',
            'statut_kyc',
            'est_actif',
            'created_at',
        )

    def get_note_moyenne(self, obj) -> float:
        avis = obj.avis.all()
        if avis.exists():
            return round(sum(a.note for a in avis) / avis.count(), 1)
        return 5.0

    def get_total_avis(self, obj) -> int:
        return obj.avis.count()

    def get_derniers_avis(self, obj):
        avis = obj.avis.all().order_by('-created_at')[:5]
        return AvisPublicSerializer(avis, many=True).data


class DepotUpdateSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField(required=False, write_only=True)
    longitude = serializers.FloatField(required=False, write_only=True)

    class Meta:
        model = Depot
        fields = (
            'nom',
            'adresse',
            'quartier',
            'telephone',
            'marque',
            'prix_6kg',
            'prix_12kg',
            'latitude',
            'longitude',
        )

    def update(self, instance, validated_data):
        lat = validated_data.pop('latitude', None)
        lon = validated_data.pop('longitude', None)
        if lat is not None and lon is not None:
            instance.localisation = Point(float(lon), float(lat), srid=4326)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()
        return instance


class DepotStockUpdateSerializer(serializers.Serializer):
    stock_6kg = serializers.IntegerField(min_value=0)
    stock_12kg = serializers.IntegerField(min_value=0)

