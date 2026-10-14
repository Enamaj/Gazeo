from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils import timezone
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
    list_display = ('gerant', 'statut', 'date_soumission', 'date_decision', 'valide_par')
    list_filter = ('statut', 'date_soumission')
    search_fields = ('gerant__telephone', 'gerant__username')
    readonly_fields = ('date_soumission',)
    actions = ['valider_kyc', 'rejeter_kyc']

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
