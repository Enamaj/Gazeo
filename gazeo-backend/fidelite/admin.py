from django.contrib import admin
from .models import Transaction


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('user', 'type', 'points', 'commande', 'created_at')
    list_filter = ('type', 'created_at')
    search_fields = ('user__telephone',)
