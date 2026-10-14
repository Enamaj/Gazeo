from django.contrib import admin
from .models import DeviceToken, NotificationLog


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'token_snippet', 'device_type', 'is_active', 'updated_at')
    list_filter = ('device_type', 'is_active')
    search_fields = ('user__telephone', 'token')

    def token_snippet(self, obj):
        return f"{obj.token[:20]}..."
    token_snippet.short_description = "Token"


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = ('titre', 'user', 'statut', 'message_id', 'created_at')
    list_filter = ('statut', 'created_at')
    search_fields = ('user__telephone', 'titre', 'corps', 'message_id')
    readonly_fields = ('user', 'titre', 'corps', 'data', 'statut', 'message_id', 'created_at')
