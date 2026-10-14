from rest_framework import serializers
from .models import Commande, SuiviPosition, StatutCommande
from auth_user.serializers import UserProfileSerializer


class CreerCommandeSerializer(serializers.Serializer):
    depot_id = serializers.IntegerField()
    quantite_6kg = serializers.IntegerField(min_value=0, default=0)
    quantite_12kg = serializers.IntegerField(min_value=0, default=0)
    adresse_livraison = serializers.CharField(max_length=255)
    latitude_livraison = serializers.FloatField()
    longitude_livraison = serializers.FloatField()

    def validate(self, attrs):
        q6 = attrs.get('quantite_6kg', 0)
        q12 = attrs.get('quantite_12kg', 0)
        if q6 == 0 and q12 == 0:
            raise serializers.ValidationError("Vous devez commander au moins une bouteille (6kg ou 12.5kg).")
        return attrs


class ConfirmerLivraisonSerializer(serializers.Serializer):
    code_otp = serializers.CharField(min_length=6, max_length=6)


class AccepterCommandeSerializer(serializers.Serializer):
    livreur_id = serializers.IntegerField(required=False, allow_null=True)


class SuiviPositionInputSerializer(serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()


class SuiviPositionSerializer(serializers.ModelSerializer):
    livreur_telephone = serializers.CharField(source='livreur.telephone', read_only=True)

    class Meta:
        model = SuiviPosition
        fields = ('id', 'livreur_telephone', 'latitude', 'longitude', 'timestamp')


class CommandeDetailSerializer(serializers.ModelSerializer):
    client = UserProfileSerializer(read_only=True)
    depot_nom = serializers.CharField(source='depot.nom', read_only=True)
    depot_quartier = serializers.CharField(source='depot.quartier', read_only=True)
    depot_telephone = serializers.CharField(source='depot.telephone', read_only=True)
    livreur_telephone = serializers.CharField(source='livreur.telephone', read_only=True, allow_null=True)
    derniere_position = serializers.SerializerMethodField()

    class Meta:
        model = Commande
        fields = (
            'id',
            'client',
            'depot',
            'depot_nom',
            'depot_quartier',
            'depot_telephone',
            'livreur',
            'livreur_telephone',
            'quantite_6kg',
            'quantite_12kg',
            'montant_total',
            'frais_livraison',
            'statut',
            'adresse_livraison',
            'latitude_livraison',
            'longitude_livraison',
            'code_confirmation',
            'derniere_position',
            'created_at',
            'updated_at',
        )

    def get_derniere_position(self, obj):
        derniere = obj.positions.first()
        if derniere:
            return {
                'latitude': derniere.latitude,
                'longitude': derniere.longitude,
                'timestamp': derniere.timestamp,
            }
        return None


class CommandeGerantSerializer(serializers.ModelSerializer):
    client_telephone = serializers.CharField(source='client.telephone', read_only=True)
    client_nom = serializers.CharField(source='client.username', read_only=True)
    livreur_telephone = serializers.CharField(source='livreur.telephone', read_only=True, allow_null=True)

    class Meta:
        model = Commande
        fields = (
            'id',
            'client_telephone',
            'client_nom',
            'livreur_telephone',
            'quantite_6kg',
            'quantite_12kg',
            'montant_total',
            'frais_livraison',
            'statut',
            'adresse_livraison',
            'latitude_livraison',
            'longitude_livraison',
            'code_confirmation',
            'created_at',
            'updated_at',
        )


class DisponibiliteSerializer(serializers.Serializer):
    est_disponible = serializers.BooleanField(required=False)


class MissionLivreurSerializer(serializers.ModelSerializer):
    depot_id = serializers.IntegerField(source='depot.id', read_only=True)
    depot_nom = serializers.CharField(source='depot.nom', read_only=True)
    depot_adresse = serializers.CharField(source='depot.adresse', read_only=True)
    depot_quartier = serializers.CharField(source='depot.quartier', read_only=True)
    depot_telephone = serializers.CharField(source='depot.telephone', read_only=True)
    depot_latitude = serializers.SerializerMethodField()
    depot_longitude = serializers.SerializerMethodField()
    client_telephone = serializers.CharField(source='client.telephone', read_only=True)
    client_nom = serializers.CharField(source='client.username', read_only=True)

    class Meta:
        model = Commande
        fields = (
            'id',
            'depot_id',
            'depot_nom',
            'depot_adresse',
            'depot_quartier',
            'depot_telephone',
            'depot_latitude',
            'depot_longitude',
            'client_telephone',
            'client_nom',
            'quantite_6kg',
            'quantite_12kg',
            'montant_total',
            'frais_livraison',
            'statut',
            'adresse_livraison',
            'latitude_livraison',
            'longitude_livraison',
            'code_confirmation',
            'created_at',
            'updated_at',
        )

    def get_depot_latitude(self, obj):
        return obj.depot.localisation.y if obj.depot and obj.depot.localisation else None

    def get_depot_longitude(self, obj):
        return obj.depot.localisation.x if obj.depot and obj.depot.localisation else None

