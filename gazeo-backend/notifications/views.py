from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import NotificationLog
from .serializers import EnregistrerTokenSerializer, NotificationLogSerializer
from .services.fcm_service import FCMService


class EnregistrerTokenView(APIView):
    """
    POST /notifications/token/
    Enregistre ou met à jour le token FCM de l'utilisateur connecté.
    Supporte multi-appareils (Android, iOS, Web).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = EnregistrerTokenSerializer(data=request.data)
        if serializer.is_valid():
            token = serializer.validated_data['token']
            device_type = serializer.validated_data.get('device_type', 'android')
            device_token = FCMService.enregistrer_token(
                user=request.user,
                token=token,
                device_type=device_type
            )
            return Response(
                {
                    "message": "Token FCM enregistré avec succès",
                    "device_type": device_token.device_type,
                    "token": device_token.token[:15] + "..."
                },
                status=status.HTTP_200_OK
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MesNotificationsView(APIView):
    """
    GET /notifications/mes-notifications/
    Liste des dernières notifications reçues par l'utilisateur connecté.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        logs = NotificationLog.objects.filter(user=request.user).order_by('-created_at')[:50]
        serializer = NotificationLogSerializer(logs, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
