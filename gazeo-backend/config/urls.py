"""
URL configuration for GAZEO backend.
"""
from django.contrib import admin
from django.urls import path, include
from depots.urls import depot_patterns, gerant_patterns
from commandes.urls import commande_patterns, livraison_patterns, livreur_patterns

from commandes.analytics_views import DailyAnalyticsView
from config.views import HealthCheckView, MigrateView

handler500 = 'config.views.custom_error_500'

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='health_check'),
    path('system/migrate/', MigrateView.as_view(), name='system_migrate'),
    path('admin/analytics/daily/', DailyAnalyticsView.as_view(), name='admin_daily_analytics'),
    path('admin/', admin.site.urls),

    path('auth/', include('auth_user.urls')),
    path('depots/', include((depot_patterns, 'depots'))),
    path('gerants/', include((gerant_patterns, 'gerants'))),
    path('commandes/', include((commande_patterns, 'commandes'))),
    path('livraisons/', include((livraison_patterns, 'livraisons'))),
    path('livreurs/', include((livreur_patterns, 'livreurs'))),
    path('paiements/', include('paiements.urls')),
    path('notifications/', include('notifications.urls')),
]

