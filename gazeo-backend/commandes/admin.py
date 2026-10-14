import csv
from django.contrib import admin
from django.http import HttpResponse
from .models import Commande, SuiviPosition


@admin.action(description="📊 Exporter les commandes sélectionnées en CSV")
def exporter_commandes_csv(modeladmin, request, queryset):
    response = HttpResponse(content_type='text/csv; charset=utf-8')
    response['Content-Disposition'] = 'attachment; filename="commandes_gazeo.csv"'
    writer = csv.writer(response)
    writer.writerow([
        'ID Commande',
        'Date Création',
        'Téléphone Client',
        'Nom Dépôt',
        'Téléphone Livreur',
        'Qté 6kg',
        'Qté 12.5kg',
        'Montant Total (FCFA)',
        'Frais Livraison (FCFA)',
        'Commission GAZEO (1.5%)',
        'Statut',
        'Adresse de Livraison',
    ])
    for cmd in queryset:
        commission = round(float(cmd.montant_total) * 0.015, 2)
        writer.writerow([
            cmd.id,
            cmd.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            cmd.client.telephone if cmd.client else '',
            cmd.depot.nom if cmd.depot else '',
            cmd.livreur.telephone if cmd.livreur else 'Non assigné',
            cmd.quantite_6kg,
            cmd.quantite_12kg,
            cmd.montant_total,
            cmd.frais_livraison,
            commission,
            cmd.get_statut_display(),
            cmd.adresse_livraison,
        ])
    return response


@admin.register(Commande)
class CommandeAdmin(admin.ModelAdmin):
    list_display = ('id', 'client', 'depot', 'livreur', 'montant_total', 'statut', 'created_at')
    list_filter = ('statut', 'created_at', 'depot__nom')
    search_fields = ('client__telephone', 'depot__nom', 'code_confirmation')
    actions = [exporter_commandes_csv]


@admin.register(SuiviPosition)
class SuiviPositionAdmin(admin.ModelAdmin):
    list_display = ('commande', 'livreur', 'latitude', 'longitude', 'timestamp')
    list_filter = ('timestamp',)
    search_fields = ('commande__id', 'livreur__telephone')
