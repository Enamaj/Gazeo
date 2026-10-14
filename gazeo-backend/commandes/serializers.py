from rest_framework import serializers
from .models import Commande


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

