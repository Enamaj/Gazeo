from rest_framework import serializers
from .models import DeviceToken, NotificationLog


class EnregistrerTokenSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255, required=True)
    device_type = serializers.ChoiceField(
        choices=[('android', 'Android'), ('ios', 'iOS'), ('web', 'Web')],
        default='android'
    )


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ['id', 'token', 'device_type', 'is_active', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class NotificationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationLog
        fields = ['id', 'titre', 'corps', 'data', 'statut', 'created_at']
        read_only_fields = ['id', 'titre', 'corps', 'data', 'statut', 'created_at']
