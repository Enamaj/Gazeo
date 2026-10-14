import csv
from django.contrib import admin
from django.http import HttpResponse
from .models import Paiement, VirementHebdomadaire


@admin.action(description="📊 Exporter les virements gérants en CSV")
def exporter_virements_csv(modeladmin, request, queryset):
    response = HttpResponse(content_type='text/csv; charset=utf-8')
    response['Content-Disposition'] = 'attachment; filename="virements_gerants_gazeo.csv"'
    writer = csv.writer(response)
    writer.writerow([
        'ID Virement',
        'Gérant',
        'Téléphone Gérant',
        'Période Début',
        'Période Fin',
        'Total Brut (FCFA)',
        'Commission GAZEO (1.5%)',
        'Net à Verser (FCFA)',
        'Statut',
        'Date Virement',
        'Référence Virement',
    ])
    for vir in queryset:
        writer.writerow([
            vir.id,
            vir.gerant.nom if hasattr(vir.gerant, 'nom') else str(vir.gerant),
            vir.gerant.telephone if vir.gerant else '',
            vir.periode_debut,
            vir.periode_fin,
            vir.total_brut,
            vir.commission_gazeo,
            vir.net_a_verser,
            vir.statut,
            vir.date_virement.strftime('%Y-%m-%d %H:%M') if vir.date_virement else '',
            vir.reference_virement or '',
        ])
    return response


@admin.register(Paiement)
class PaiementAdmin(admin.ModelAdmin):
    list_display = ('reference_notchpay', 'commande', 'methode', 'statut', 'montant', 'commission_gazeo', 'montant_net_gerant', 'created_at')
    list_filter = ('methode', 'statut', 'created_at')
    search_fields = ('reference_notchpay', 'commande__id')


@admin.register(VirementHebdomadaire)
class VirementHebdomadaireAdmin(admin.ModelAdmin):
    list_display = ('id', 'gerant', 'periode_debut', 'periode_fin', 'total_brut', 'commission_gazeo', 'net_a_verser', 'statut')
    list_filter = ('statut', 'periode_fin')
    search_fields = ('gerant__telephone', 'reference_virement')
    actions = [exporter_virements_csv]
