from rest_framework import serializers
from .models import Paiement, VirementHebdomadaire


class InitierPaiementSerializer(serializers.Serializer):
    commande_id = serializers.IntegerField()
    telephone = serializers.CharField(max_length=25, required=False)


class RembourserPaiementSerializer(serializers.Serializer):
    motif = serializers.CharField(max_length=255, required=False, default="Annulation de commande")


class PaiementDetailSerializer(serializers.ModelSerializer):
    commande_id = serializers.IntegerField(source='commande.id', read_only=True)
    client_telephone = serializers.CharField(source='commande.client.telephone', read_only=True)

    class Meta:
        model = Paiement
        fields = (
            'id',
            'commande_id',
            'client_telephone',
            'reference_notchpay',
            'methode',
            'statut',
            'montant',
            'commission_gazeo',
            'montant_net_gerant',
            'created_at',
            'rembourse_at',
            'motif_remboursement',
        )


class VirementHebdomadaireSerializer(serializers.ModelSerializer):
    gerant_telephone = serializers.CharField(source='gerant.telephone', read_only=True)

    class Meta:
        model = VirementHebdomadaire
        fields = (
            'id',
            'gerant_telephone',
            'periode_debut',
            'periode_fin',
            'total_brut',
            'commission_gazeo',
            'net_a_verser',
            'statut',
            'date_virement',
            'reference_virement',
        )

