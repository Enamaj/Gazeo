from django.urls import path
from .views import (
    InitierPaiementView,
    NotchpayWebhookView,
    RembourserPaiementView,
    CalculerVirementsHebdomadairesView,
)

urlpatterns = [
    path('initier/', InitierPaiementView.as_view(), name='paiement_initier'),
    path('webhook/notchpay/', NotchpayWebhookView.as_view(), name='notchpay_webhook'),
    path('<int:pk>/rembourser/', RembourserPaiementView.as_view(), name='paiement_rembourser'),
    path('virements-gerants/calcul/', CalculerVirementsHebdomadairesView.as_view(), name='virements_calcul'),
]

