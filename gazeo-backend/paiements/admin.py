import csv
from django.contrib import admin
from django.http import HttpResponse
from django.utils.html import format_html
from .models import Paiement, VirementHebdomadaire, VirementCommande


@admin.register(VirementCommande)
class VirementCommandeAdmin(admin.ModelAdmin):
    list_display = ('id', 'commande_link', 'type_badge', 'beneficiaire', 'montant_badge', 'statut_badge', 'reference_transfert', 'created_at')
    list_filter = ('type_virement', 'statut', 'created_at')
    search_fields = ('commande__id', 'beneficiaire', 'reference_transfert')
    readonly_fields = ('created_at',)

    def commande_link(self, obj):
        return format_html('<a href="/admin/commandes/commande/{}/change/">Commande #{}</a>', obj.commande_id, obj.commande_id)
    commande_link.short_description = "Commande"

    def type_badge(self, obj):
        colors = {'GERANT_MOMO': '#2563eb', 'GAZEO_COMMISSION': '#f97316'}
        return format_html('<span style="background:{}; color:white; padding:3px 8px; border-radius:6px; font-size:11px; font-weight:700;">{}</span>', colors.get(obj.type_virement, '#64748b'), obj.get_type_virement_display())
    type_badge.short_description = "Type"

    def montant_badge(self, obj):
        return format_html('<strong>{:,} FCFA</strong>', obj.montant).replace(',', ' ')
    montant_badge.short_description = "Montant"

    def statut_badge(self, obj):
        colors = {'VIRE': '#10b981', 'EN_ATTENTE': '#f59e0b', 'ECHOUE': '#ef4444'}
        return format_html('<span style="background:{}; color:white; padding:3px 8px; border-radius:6px; font-size:11px; font-weight:700;">{}</span>', colors.get(obj.statut, '#64748b'), obj.get_statut_display())
    statut_badge.short_description = "Statut"


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
