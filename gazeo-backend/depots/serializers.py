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
    image_depot_url = serializers.SerializerMethodField()
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
            'marques_disponibles',
            'image_depot_url',
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

    def get_image_depot_url(self, obj) -> str | None:
        return obj.image_depot.url if obj.image_depot else None

    def get_distance_metres(self, obj) -> float | None:
        if hasattr(obj, 'distance') and obj.distance is not None:
            if hasattr(obj.distance, 'm'):
                return round(float(obj.distance.m), 1)
            return round(float(obj.distance), 1)
        return None

    def get_distance_km(self, obj) -> float | None:
        if hasattr(obj, 'distance') and obj.distance is not None:
            if hasattr(obj.distance, 'km'):
                return round(float(obj.distance.km), 2)
            return round(float(obj.distance) / 1000.0, 2)
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
    image_depot_url = serializers.SerializerMethodField()

    class Meta:
        model = Depot
        fields = (
            'id',
            'nom',
            'adresse',
            'quartier',
            'telephone',
            'marque',
            'marques_disponibles',
            'image_depot_url',
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

    def get_image_depot_url(self, obj) -> str | None:
        return obj.image_depot.url if obj.image_depot else None

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


class DepotProfileSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField(write_only=True)
    longitude = serializers.FloatField(write_only=True)
    marques_disponibles = serializers.ListField(
        child=serializers.ChoiceField(choices=MarqueGaz.choices),
        allow_empty=True,
    )
    image_depot = serializers.ImageField(required=False)

    class Meta:
        model = Depot
        fields = (
            'nom',
            'adresse',
            'quartier',
            'marques_disponibles',
            'image_depot',
            'prix_6kg',
            'prix_12kg',
            'latitude',
            'longitude',
        )
        extra_kwargs = {
            'nom': {'required': True},
            'adresse': {'required': True},
            'quartier': {'required': True},
            'prix_6kg': {'required': False},
            'prix_12kg': {'required': False},
        }

    def validate(self, attrs):
        latitude = attrs.get('latitude')
        longitude = attrs.get('longitude')
        if self.instance:
            latitude = latitude if latitude is not None else self.instance.latitude
            longitude = longitude if longitude is not None else self.instance.longitude
        if latitude is None or longitude is None:
            raise serializers.ValidationError(
                "La géolocalisation du dépôt est obligatoire."
            )
        if not (
            1.6 <= latitude <= 13.1
            and 8.4 <= longitude <= 16.2
        ):
            raise serializers.ValidationError(
                "La position du dépôt doit se trouver au Cameroun."
            )
        if self.instance is None and not attrs.get('image_depot'):
            raise serializers.ValidationError(
                {"image_depot": "Ajoutez une photo du dépôt."}
            )
        if self.instance is None and not attrs.get('marques_disponibles'):
            raise serializers.ValidationError(
                {"marques_disponibles": "Sélectionnez au moins une marque en stock."}
            )
        image = attrs.get('image_depot')
        if image and image.size > 10 * 1024 * 1024:
            raise serializers.ValidationError(
                {"image_depot": "La taille maximale de l’image est de 10 Mo."}
            )
        return attrs

    def create(self, validated_data):
        latitude = validated_data.pop('latitude')
        longitude = validated_data.pop('longitude')
        validated_data['marque'] = validated_data['marques_disponibles'][0]
        depot = Depot.objects.create(
            **validated_data,
            gerant=self.context['request'].user,
            telephone=self.context['request'].user.telephone,
            localisation=Point(longitude, latitude, srid=4326),
            statut_kyc=StatutKYC.VALIDE,
            est_actif=True,
        )
        return depot

    def update(self, instance, validated_data):
        latitude = validated_data.pop('latitude', instance.latitude)
        longitude = validated_data.pop('longitude', instance.longitude)
        instance.localisation = Point(longitude, latitude, srid=4326)
        marques = validated_data.get('marques_disponibles')
        if marques is not None:
            if marques:
                instance.marque = marques[0]
            instance.marques_disponibles = marques
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance
