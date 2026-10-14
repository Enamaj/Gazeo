from django.urls import path
from .views import (
    CreerCommandeView,
    AccepterCommandeView,
    ConfirmerCommandeView,
    AnnulerCommandeView,
    MesCommandesView,
    MettreAJourPositionLivreurView,
    PositionActuelleLivreurView,
    RecupererStockCommandeView,
    MissionsDisponiblesView,
    TableauBordLivreurView,
    ToggleDisponibiliteLivreurView,
    HistoriqueLivreurView,
)

commande_patterns = [
    path('creer/', CreerCommandeView.as_view(), name='commande_creer'),
    path('missions-disponibles/', MissionsDisponiblesView.as_view(), name='commandes_missions_disponibles'),
    path('<int:pk>/accepter/', AccepterCommandeView.as_view(), name='commande_accepter'),
    path('<int:pk>/recuperer-stock/', RecupererStockCommandeView.as_view(), name='commande_recuperer_stock'),
    path('<int:pk>/confirmer/', ConfirmerCommandeView.as_view(), name='commande_confirmer'),
    path('<int:pk>/annuler/', AnnulerCommandeView.as_view(), name='commande_annuler'),
    path('mes-commandes/', MesCommandesView.as_view(), name='mes_commandes'),
]

livraison_patterns = [
    path('<int:commande_id>/position/', MettreAJourPositionLivreurView.as_view(), name='livraison_position_update'),
    path('<int:pk>/position-actuelle/', PositionActuelleLivreurView.as_view(), name='livraison_position_actuelle'),
]

livreur_patterns = [
    path('tableau-de-bord/', TableauBordLivreurView.as_view(), name='livreur_tableau_de_bord'),
    path('disponibilite/', ToggleDisponibiliteLivreurView.as_view(), name='livreur_disponibilite'),
    path('missions/', MissionsDisponiblesView.as_view(), name='livreur_missions'),
    path('historique/', HistoriqueLivreurView.as_view(), name='livreur_historique'),
]


