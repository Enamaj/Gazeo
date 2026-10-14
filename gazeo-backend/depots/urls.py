from django.urls import path
from .views import (
    DepotsProchesView,
    DepotDetailView,
    DepotAvisListView,
    GerantMonDepotView,
    GerantStockUpdateView,
    GerantCommandesView,
)
from auth_user.views import (
    GerantKYCSoumettreView,
    GerantKYCStatutView,
)

depot_patterns = [
    path('proches/', DepotsProchesView.as_view(), name='depots_proches'),
    path('<int:pk>/', DepotDetailView.as_view(), name='depot_detail'),
    path('<int:pk>/avis/', DepotAvisListView.as_view(), name='depot_avis'),
]

gerant_patterns = [
    path('mon-depot/', GerantMonDepotView.as_view(), name='gerant_mon_depot'),
    path('mon-depot/stock/', GerantStockUpdateView.as_view(), name='gerant_stock_update'),
    path('commandes/', GerantCommandesView.as_view(), name='gerant_commandes'),
    path('kyc/soumettre/', GerantKYCSoumettreView.as_view(), name='gerant_kyc_soumettre'),
    path('kyc/statut/', GerantKYCStatutView.as_view(), name='gerant_kyc_statut'),
]
