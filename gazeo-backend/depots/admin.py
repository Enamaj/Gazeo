from django.contrib import admin
from .models import Depot


@admin.register(Depot)
class DepotAdmin(admin.ModelAdmin):
    list_display = ('nom', 'quartier', 'marque', 'gerant', 'stock_6kg', 'stock_12kg', 'statut_kyc', 'est_actif')
    list_filter = ('marque', 'statut_kyc', 'est_actif', 'quartier')
    search_fields = ('nom', 'quartier', 'telephone', 'gerant__telephone')
