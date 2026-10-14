import logging
from datetime import timedelta
from decimal import Decimal
from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from auth_user.models import User, UserRole, GerantKYC, StatutKYC
from depots.models import Depot
from .models import Commande, StatutCommande

logger = logging.getLogger(__name__)


class DailyAnalyticsView(APIView):
    """
    GET /admin/analytics/daily/
    Endpoint sécurisé pour administrateurs fournissant les KPIs temps réel de la plateforme GAZEO :
    - Commandes aujourd'hui et Chiffre d'Affaires (FCFA)
    - Commissions GAZEO perçues (1.5%)
    - Dépôts avec stock épuisé
    - Gérants en attente de validation KYC (liste cliquable)
    - Taux de livraison réussie sur les 7 derniers jours
    - Nombre de livreurs disponibles
    """
    permission_classes = [permissions.IsAuthenticated, permissions.IsAdminUser]

    def get(self, request):
        today = timezone.localdate()
        sept_jours_avant = timezone.now() - timedelta(days=7)

        # 1. Commandes et CA du jour
        commandes_today = Commande.objects.filter(created_at__date=today)
        nb_commandes_jour = commandes_today.count()
        ca_jour = sum((c.montant_total for c in commandes_today), Decimal('0.00'))
        commissions_jour = round(float(ca_jour) * 0.015, 2)

        # 2. Dépôts en rupture totale de stock
        depots_rupture_qs = Depot.objects.filter(est_actif=True, stock_6kg=0, stock_12kg=0)
        nb_depots_rupture = depots_rupture_qs.count()
        depots_rupture_liste = list(
            depots_rupture_qs.values('id', 'nom', 'quartier', 'telephone')[:10]
        )

        # 3. Gérants en attente de KYC
        kyc_en_attente_qs = GerantKYC.objects.filter(statut=StatutKYC.EN_ATTENTE).select_related('gerant')
        nb_kyc_en_attente = kyc_en_attente_qs.count()
        kyc_liste = [
            {
                'kyc_id': k.id,
                'gerant_id': k.gerant.id,
                'telephone': k.gerant.telephone,
                'nom': k.gerant.username or 'Sans nom',
                'date_soumission': k.date_soumission.strftime('%Y-%m-%d %H:%M'),
                'admin_url': f"/admin/auth_user/gerantkyc/{k.id}/change/"
            }
            for k in kyc_en_attente_qs[:20]
        ]

        # 4. Taux de livraison réussie sur les 7 derniers jours
        commandes_7j = Commande.objects.filter(created_at__gte=sept_jours_avant)
        livrees_7j = commandes_7j.filter(statut=StatutCommande.LIVREE).count()
        annulees_7j = commandes_7j.filter(statut=StatutCommande.ANNULEE).count()
        total_terminees_7j = livrees_7j + annulees_7j
        taux_reussite = (
            round((livrees_7j / total_terminees_7j) * 100, 1)
            if total_terminees_7j > 0
            else 100.0
        )

        # 5. Livreurs disponibles
        livreurs_dispo = User.objects.filter(
            role=UserRole.LIVREUR,
            est_disponible=True,
            is_active=True
        ).count()

        data = {
            "date": today.isoformat(),
            "commandes_aujourdhui": nb_commandes_jour,
            "chiffre_affaires_aujourdhui": float(ca_jour),
            "commissions_gazeo_aujourdhui": commissions_jour,
            "depots_en_rupture": {
                "count": nb_depots_rupture,
                "liste": depots_rupture_liste
            },
            "gerants_kyc_en_attente": {
                "count": nb_kyc_en_attente,
                "liste": kyc_liste
            },
            "taux_livraison_reussie_7j": taux_reussite,
            "commandes_livrees_7j": livrees_7j,
            "commandes_annulees_7j": annulees_7j,
            "livreurs_disponibles": livreurs_dispo
        }

        return Response(data, status=status.HTTP_200_OK)

