from django.contrib import admin
from django.contrib.gis import admin as gis_admin
from django.utils.html import format_html
from .models import Depot, StatutKYC


@gis_admin.register(Depot)
class DepotAdmin(gis_admin.GISModelAdmin):
    list_display = ('nom', 'quartier', 'marque', 'gerant', 'stock_6kg', 'stock_12kg', 'statut_badge', 'actif_badge')
    list_filter = ('marque', 'statut_kyc', 'est_actif', 'quartier')
    search_fields = ('nom', 'quartier', 'telephone', 'gerant__telephone')
    actions = ['activer_depots', 'desactiver_depots', 'valider_kyc_depots']

    def statut_badge(self, obj):
        colors = {
            StatutKYC.VALIDE: '#16a34a',
            StatutKYC.EN_ATTENTE: '#f59e0b',
            StatutKYC.REJETE: '#dc2626',
        }
        color = colors.get(obj.statut_kyc, '#6b7280')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 10px; font-weight: bold; font-size: 11px;">{}</span>',
            color,
            obj.get_statut_kyc_display()
        )
    statut_badge.short_description = "KYC"

    def actif_badge(self, obj):
        if obj.est_actif:
            return format_html('<span style="color: #16a34a; font-weight: bold;">● Actif</span>')
        return format_html('<span style="color: #dc2626; font-weight: bold;">○ Inactif</span>')
    actif_badge.short_description = "Visibilité Carte"

    @admin.action(description="🟢 Activer et rendre visible sur la carte")
    def activer_depots(self, request, queryset):
        mis_a_jour = queryset.update(est_actif=True)
        self.message_user(request, f"{mis_a_jour} dépôt(s) activé(s) sur la carte.")

    @admin.action(description="🔴 Désactiver et masquer de la carte")
    def desactiver_depots(self, request, queryset):
        mis_a_jour = queryset.update(est_actif=False)
        self.message_user(request, f"{mis_a_jour} dépôt(s) désactivé(s).")

    @admin.action(description="✅ Valider le KYC et activer les dépôts sélectionnés")
    def valider_kyc_depots(self, request, queryset):
        mis_a_jour = queryset.update(statut_kyc=StatutKYC.VALIDE, est_actif=True)
        self.message_user(request, f"{mis_a_jour} dépôt(s) validé(s) et activé(s).")
