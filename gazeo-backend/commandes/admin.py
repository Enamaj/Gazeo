from django.contrib import admin
from .models import Commande


@admin.register(Commande)
class CommandeAdmin(admin.ModelAdmin):
    list_display = ('id', 'client', 'depot', 'livreur', 'montant_total', 'statut', 'created_at')
    list_filter = ('statut', 'created_at')
    search_fields = ('client__telephone', 'depot__nom', 'code_confirmation')
