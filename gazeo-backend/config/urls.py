"""
URL configuration for GAZEO backend.
"""
from django.contrib import admin
from django.urls import path, include
from depots.urls import depot_patterns, gerant_patterns
from commandes.urls import commande_patterns, livraison_patterns

urlpatterns = [
    path('admin/', admin.site.urls),
    path('auth/', include('auth_user.urls')),
    path('depots/', include((depot_patterns, 'depots'))),
    path('gerants/', include((gerant_patterns, 'gerants'))),
    path('commandes/', include((commande_patterns, 'commandes'))),
    path('livraisons/', include((livraison_patterns, 'livraisons'))),
]
