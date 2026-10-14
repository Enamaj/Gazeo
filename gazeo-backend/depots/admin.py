from django.contrib.gis import admin as gis_admin
from .models import Depot


@gis_admin.register(Depot)
class DepotAdmin(gis_admin.GISModelAdmin):
    list_display = ('nom', 'quartier', 'marque', 'gerant', 'stock_6kg', 'stock_12kg', 'statut_kyc', 'est_actif')
    list_filter = ('marque', 'statut_kyc', 'est_actif', 'quartier')
    search_fields = ('nom', 'quartier', 'telephone', 'gerant__telephone')
