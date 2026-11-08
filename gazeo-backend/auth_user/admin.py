from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils import timezone
from django.utils.html import format_html
from .models import User, GerantKYC, StatutKYC
from .services.sms_service import TwilioSMSService
from depots.models import Depot, StatutKYC as DepotStatutKYC

sms_service = TwilioSMSService()


import csv
from django.http import HttpResponse


@admin.action(description="📊 Exporter les utilisateurs sélectionnés en CSV")
def exporter_utilisateurs_csv(modeladmin, request, queryset):
    response = HttpResponse(content_type='text/csv; charset=utf-8')
    response['Content-Disposition'] = 'attachment; filename="utilisateurs_gazeo.csv"'
    writer = csv.writer(response)
    writer.writerow([
        'ID',
        'Téléphone',
        'Nom d\'utilisateur',
        'Rôle',
        'Numéro Vérifié',
        'Points Fidélité',
        'Est Actif',
        'Date d\'inscription',
        'Dernière Connexion',
    ])
    for u in queryset:
        writer.writerow([
            u.id,
            u.telephone,
            u.username,
            u.get_role_display(),
            'Oui' if u.is_verified else 'Non',
            u.points_fidelite,
            'Oui' if u.is_active else 'Non',
            u.date_joined.strftime('%Y-%m-%d %H:%M:%S'),
            u.last_login.strftime('%Y-%m-%d %H:%M:%S') if u.last_login else 'Jamais',
        ])
    return response


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('telephone', 'username', 'role', 'is_verified', 'points_fidelite', 'is_staff', 'date_joined')
    list_filter = ('role', 'is_verified', 'is_staff', 'is_active')
    search_fields = ('telephone', 'username', 'email')
    ordering = ('-date_joined',)
    actions = [exporter_utilisateurs_csv]
    fieldsets = (
        (None, {'fields': ('telephone', 'password')}),
        ('Informations personnelles', {'fields': ('username', 'first_name', 'last_name', 'email')}),
        ('Rôles & Privilèges GAZEO', {'fields': ('role', 'is_verified', 'est_disponible', 'points_fidelite', 'fcm_token')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Dates importantes', {'fields': ('last_login', 'date_joined')}),
    )



@admin.register(GerantKYC)
class GerantKYCAdmin(admin.ModelAdmin):
    list_display = ('gerant', 'statut_badge', 'date_soumission', 'date_decision', 'valide_par')
    list_filter = ('statut', 'date_soumission')
    search_fields = ('gerant__telephone', 'gerant__username')
    readonly_fields = (
        'date_soumission',
        'apercu_cni_recto',
        'apercu_cni_verso',
        'apercu_photo_depot',
        'apercu_photo_interieur',
        'apercu_document_commercial',
    )
    fieldsets = (
        ('Gérant & Statut', {
            'fields': ('gerant', 'statut', 'raison_rejet', 'valide_par', 'date_decision', 'date_soumission')
        }),
        ('Documents d\'identité (CNI)', {
            'fields': (('cni_recto', 'apercu_cni_recto'), ('cni_verso', 'apercu_cni_verso'))
        }),
        ('Photos du Dépôt de gaz', {
            'fields': (('photo_depot', 'apercu_photo_depot'), ('photo_depot_interieur', 'apercu_photo_interieur'))
        }),
        ('Document Commercial / Registre', {
            'fields': (('document_commercial', 'apercu_document_commercial'),)
        }),
    )
    actions = ['valider_kyc', 'rejeter_kyc']

    def statut_badge(self, obj):
        colors = {
            StatutKYC.VALIDE: '#16a34a',
            StatutKYC.EN_ATTENTE: '#f59e0b',
            StatutKYC.REJETE: '#dc2626',
        }
        color = colors.get(obj.statut, '#6b7280')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 4px 10px; border-radius: 12px; font-weight: bold; font-size: 11px;">{}</span>',
            color,
            obj.get_statut_display()
        )
    statut_badge.short_description = "Statut KYC"

    def _render_image_preview(self, field_value, label="Aperçu"):
        if not field_value:
            return format_html('<span style="color: #9ca3af; font-style: italic;">Aucun document téléversé</span>')
        try:
            url = getattr(field_value, 'url', str(field_value))
            if not url.startswith('http'):
                url = f"https://res.cloudinary.com/dummy/image/upload/{url}"
            return format_html(
                '<a href="{}" target="_blank" title="Cliquer pour agrandir">'
                '<img src="{}" style="max-height: 140px; max-width: 240px; object-fit: contain; border-radius: 8px; border: 1px solid #e5e7eb; box-shadow: 0 2px 4px rgba(0,0,0,0.08);"/>'
                '</a>',
                url, url
            )
        except Exception:
            return str(field_value)

    def apercu_cni_recto(self, obj):
        return self._render_image_preview(obj.cni_recto)
    apercu_cni_recto.short_description = "Aperçu CNI Recto"

    def apercu_cni_verso(self, obj):
        return self._render_image_preview(obj.cni_verso)
    apercu_cni_verso.short_description = "Aperçu CNI Verso"

    def apercu_photo_depot(self, obj):
        return self._render_image_preview(obj.photo_depot)
    apercu_photo_depot.short_description = "Aperçu Façade Dépôt"

    def apercu_photo_interieur(self, obj):
        return self._render_image_preview(obj.photo_depot_interieur)
    apercu_photo_interieur.short_description = "Aperçu Intérieur Dépôt"

    def apercu_document_commercial(self, obj):
        if not obj.document_commercial:
            return format_html('<span style="color: #9ca3af; font-style: italic;">Aucun document commercial</span>')
        try:
            url = getattr(obj.document_commercial, 'url', str(obj.document_commercial))
            return format_html(
                '<a href="{}" target="_blank" style="display: inline-block; padding: 6px 12px; background: #2563eb; color: white; border-radius: 6px; text-decoration: none; font-weight: bold; font-size: 12px;">📄 Ouvrir le document</a>',
                url
            )
        except Exception:
            return str(obj.document_commercial)
    apercu_document_commercial.short_description = "Document Légal"

    @admin.action(description="Valider le dossier KYC sélectionné et activer le dépôt")
    def valider_kyc(self, request, queryset):
        for kyc in queryset:
            kyc.statut = StatutKYC.VALIDE
            kyc.valide_par = request.user
            kyc.date_decision = timezone.now()
            kyc.save()

            # Activer automatiquement le dépôt associé
            Depot.objects.filter(gerant=kyc.gerant).update(
                statut_kyc=DepotStatutKYC.VALIDE,
                est_actif=True
            )

            # Envoi SMS de confirmation au gérant
            sms_service.send_sms(
                kyc.gerant.telephone,
                "Félicitations, votre dossier KYC GAZEO a été validé ! Votre dépôt est désormais actif sur la carte."
            )

        self.message_user(request, f"{queryset.count()} dossier(s) KYC validé(s) avec succès.")

    @admin.action(description="Rejeter le dossier KYC sélectionné")
    def rejeter_kyc(self, request, queryset):
        for kyc in queryset:
            kyc.statut = StatutKYC.REJETE
            kyc.valide_par = request.user
            kyc.date_decision = timezone.now()
            if not kyc.raison_rejet:
                kyc.raison_rejet = "Documents non conformes ou illisibles."
            kyc.save()

            # Désactiver le dépôt associé
            Depot.objects.filter(gerant=kyc.gerant).update(
                statut_kyc=DepotStatutKYC.REJETE,
                est_actif=False
            )

            # Envoi SMS d'information au gérant
            sms_service.send_sms(
                kyc.gerant.telephone,
                f"Votre dossier KYC GAZEO a été rejeté. Motif : {kyc.raison_rejet}"
            )

        self.message_user(request, f"{queryset.count()} dossier(s) KYC rejeté(s).")
