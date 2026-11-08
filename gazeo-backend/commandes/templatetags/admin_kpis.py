from datetime import timedelta
from decimal import Decimal
from django import template
from django.utils import timezone

from auth_user.models import GerantKYC, StatutKYC
from depots.models import Depot
from commandes.models import Commande, StatutCommande

register = template.Library()


@register.simple_tag
def get_admin_kpis():
    """
    Retourne les 4 KPIs temps réel requis pour la page d'accueil de l'administration GAZEO :
    1. Commandes aujourd'hui et CA en FCFA
    2. Gérants en attente de KYC (liste cliquable)
    3. Dépôts avec stock épuisé
    4. Taux de livraison réussie (7 derniers jours)
    Résistant aux erreurs : retourne des zéros en cas d'incident passager de BD.
    """
    try:
        today = timezone.localdate()
        sept_jours_avant = timezone.now() - timedelta(days=7)

        # 1. Commandes et CA aujourd'hui
        commandes_today = Commande.objects.filter(created_at__date=today)
        nb_commandes = commandes_today.count()
        ca_total = sum((c.montant_total for c in commandes_today), 0)

        # 2. Gérants en attente de KYC
        kyc_attente = GerantKYC.objects.filter(statut=StatutKYC.EN_ATTENTE).select_related('gerant')
        nb_kyc = kyc_attente.count()

        # 3. Dépôts avec stock épuisé
        depots_rupture = Depot.objects.filter(est_actif=True, stock_6kg=0, stock_12kg=0)
        nb_rupture = depots_rupture.count()

        # 4. Taux de livraison réussie (7 derniers jours)
        cmd_7j = Commande.objects.filter(created_at__gte=sept_jours_avant)
        livrees_7j = cmd_7j.filter(statut=StatutCommande.LIVREE).count()
        annulees_7j = cmd_7j.filter(statut=StatutCommande.ANNULEE).count()
        total_7j = livrees_7j + annulees_7j
        taux_livraison = round((livrees_7j / total_7j * 100), 1) if total_7j > 0 else 100.0

        return {
            'nb_commandes_jour': nb_commandes,
            'ca_jour': ca_total,
            'nb_kyc_attente': nb_kyc,
            'kyc_attente_liste': list(kyc_attente[:5]),
            'nb_depots_rupture': nb_rupture,
            'depots_rupture_liste': list(depots_rupture[:5]),
            'taux_livraison_7j': taux_livraison,
        }
    except Exception:
        return {
            'nb_commandes_jour': 0,
            'ca_jour': 0,
            'nb_kyc_attente': 0,
            'kyc_attente_liste': [],
            'nb_depots_rupture': 0,
            'depots_rupture_liste': [],
            'taux_livraison_7j': 100.0,
        }

