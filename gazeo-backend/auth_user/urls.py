from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    InscriptionView,
    VerifierOTPView,
    ConnexionView,
    DeconnexionView,
    ProfilView,
)

urlpatterns = [
    path('inscription/', InscriptionView.as_view(), name='auth_inscription'),
    path('verifier-otp/', VerifierOTPView.as_view(), name='auth_verifier_otp'),
    path('connexion/', ConnexionView.as_view(), name='auth_connexion'),
    path('deconnexion/', DeconnexionView.as_view(), name='auth_deconnexion'),
    path('refresh/', TokenRefreshView.as_view(), name='auth_token_refresh'),
    path('profil/', ProfilView.as_view(), name='auth_profil'),
]

