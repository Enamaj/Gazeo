from django.contrib import admin
from .models import Paiement


@admin.register(Paiement)
class PaiementAdmin(admin.ModelAdmin):
    list_display = ('reference_notchpay', 'commande', 'methode', 'statut', 'montant', 'created_at')
    list_filter = ('methode', 'statut', 'created_at')
    search_fields = ('reference_notchpay', 'commande__id')
