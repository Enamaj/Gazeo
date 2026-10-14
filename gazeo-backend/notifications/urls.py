from django.urls import path
from .views import EnregistrerTokenView, MesNotificationsView

urlpatterns = [
    path('token/', EnregistrerTokenView.as_view(), name='enregistrer_fcm_token'),
    path('mes-notifications/', MesNotificationsView.as_view(), name='mes_notifications'),
]
