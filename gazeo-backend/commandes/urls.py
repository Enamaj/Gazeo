from django.urls import path
from .views import (
    CreerCommandeView,
    AccepterCommandeView,
    ConfirmerCommandeView,
    AnnulerCommandeView,
    MesCommandesView,
    MettreAJourPositionLivreurView,
    PositionActuelleLivreurView,
)

commande_patterns = [
    path('creer/', CreerCommandeView.as_view(), name='commande_creer'),
    path('<int:pk>/accepter/', AccepterCommandeView.as_view(), name='commande_accepter'),
    path('<int:pk>/confirmer/', ConfirmerCommandeView.as_view(), name='commande_confirmer'),
    path('<int:pk>/annuler/', AnnulerCommandeView.as_view(), name='commande_annuler'),
    path('mes-commandes/', MesCommandesView.as_view(), name='mes_commandes'),
]

livraison_patterns = [
    path('<int:commande_id>/position/', MettreAJourPositionLivreurView.as_view(), name='livraison_position_update'),
    path('<int:pk>/position-actuelle/', PositionActuelleLivreurView.as_view(), name='livraison_position_actuelle'),
]

