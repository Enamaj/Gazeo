from django.contrib import admin
from .models import Avis


@admin.register(Avis)
class AvisAdmin(admin.ModelAdmin):
    list_display = ('commande', 'client', 'depot', 'note', 'created_at')
    list_filter = ('note', 'created_at')
    search_fields = ('client__telephone', 'depot__nom', 'commentaire')
