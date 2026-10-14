from decimal import Decimal
from django.contrib.gis.geos import Point
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from auth_user.models import User, UserRole
from depots.models import Depot, MarqueGaz, StatutKYC
from commandes.models import Commande, SuiviPosition, StatutCommande
from fidelite.models import Transaction, TypeTransaction


class CommandesAPITests(APITestCase):
    def setUp(self):
        self.client_user = User.objects.create_user(
            username="+237699111222",
            telephone="+237699111222",
            password="Password123!",
            role=UserRole.CLIENT,
            is_verified=True,
            is_active=True
        )
        self.gerant_user = User.objects.create_user(
            username="+237677333444",
            telephone="+237677333444",
            password="Password123!",
            role=UserRole.GERANT,
            is_verified=True,
            is_active=True
        )
        self.livreur_user = User.objects.create_user(
            username="+237655555666",
            telephone="+237655555666",
            password="Password123!",
            role=UserRole.LIVREUR,
            is_verified=True,
            is_active=True
        )

        self.depot = Depot.objects.create(
            nom="Dépôt Gaz Yaoundé Bastos",
            adresse="Avenue Bastos",
            quartier="Bastos",
            telephone="+237677333444",
            localisation=Point(11.5180, 3.8850, srid=4326),
            gerant=self.gerant_user,
            marque=MarqueGaz.TOTAL,
            stock_6kg=10,
            stock_12kg=20,
            prix_6kg=Decimal('3000.00'),
            prix_12kg=Decimal('6500.00'),
            statut_kyc=StatutKYC.VALIDE,
            est_actif=True
        )

    def test_creer_commande_success_with_atomic_stock_deduction(self):
        """Création de commande avec déduction atomique du stock et calcul financier."""
        self.client.force_authenticate(user=self.client_user)
        url = reverse('commandes:commande_creer')
        data = {
            "depot_id": self.depot.id,
            "quantite_6kg": 2,
            "quantite_12kg": 1,
            "adresse_livraison": "Bastos Rue 12, portail vert",
            "latitude_livraison": 3.8870,
            "longitude_livraison": 11.5190,
        }

        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['statut'], StatutCommande.EN_ATTENTE)

        # Montant attendu : (2 * 3000) + (1 * 6500) + 1000 = 13500 FCFA
        self.assertEqual(response.data['montant_total'], 13500.0)
        self.assertIsNotNone(response.data['code_confirmation'])

        # Vérification déduction atomique du stock
        self.depot.refresh_from_db()
        self.assertEqual(self.depot.stock_6kg, 8)   # 10 - 2
        self.assertEqual(self.depot.stock_12kg, 19) # 20 - 1

    def test_creer_commande_stock_insuffisant_fails(self):
        """Échec de la commande si le stock disponible est insuffisant."""
        self.client.force_authenticate(user=self.client_user)
        url = reverse('commandes:commande_creer')
        data = {
            "depot_id": self.depot.id,
            "quantite_6kg": 50,  # Disponible: 10
            "quantite_12kg": 0,
            "adresse_livraison": "Bastos Rue 12",
            "latitude_livraison": 3.8870,
            "longitude_livraison": 11.5190,
        }

        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Stock insuffisant", response.data['detail'])

        # Stock inchangé
        self.depot.refresh_from_db()
        self.assertEqual(self.depot.stock_6kg, 10)

    def test_accepter_commande_gerant(self):
        """Le gérant du dépôt accepte la commande et peut assigner un livreur."""
        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=Decimal('4000.00'),
            adresse_livraison="Bastos Rue 12",
            latitude_livraison=3.8870,
            longitude_livraison=11.5190,
            code_confirmation="123456"
        )
        url = reverse('commandes:commande_accepter', kwargs={'pk': commande.pk})

        self.client.force_authenticate(user=self.gerant_user)
        data = {"livreur_id": self.livreur_user.id}
        response = self.client.put(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['statut'], StatutCommande.EN_LIVRAISON)

        commande.refresh_from_db()
        self.assertEqual(commande.livreur, self.livreur_user)

    def test_confirmer_commande_livreur_and_loyalty_points(self):
        """Validation livraison avec OTP client -> Statut LIVREE et points fidélité crédités."""
        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            livreur=self.livreur_user,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=Decimal('4000.00'),
            statut=StatutCommande.EN_LIVRAISON,
            adresse_livraison="Bastos",
            latitude_livraison=3.8870,
            longitude_livraison=11.5190,
            code_confirmation="789012"
        )
        url = reverse('commandes:commande_confirmer', kwargs={'pk': commande.pk})
        self.client.force_authenticate(user=self.livreur_user)

        # Mauvais code OTP
        res_bad = self.client.put(url, {"code_otp": "000000"}, format='json')
        self.assertEqual(res_bad.status_code, status.HTTP_400_BAD_REQUEST)

        # Bon code OTP
        res_ok = self.client.put(url, {"code_otp": "789012"}, format='json')
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)
        self.assertEqual(res_ok.data['statut'], StatutCommande.LIVREE)
        self.assertEqual(res_ok.data['points_gagnes'], 10)

        # Vérification créditation solde et historique fidélité
        self.client_user.refresh_from_db()
        self.assertEqual(self.client_user.points_fidelite, 10)
        self.assertTrue(Transaction.objects.filter(user=self.client_user, type=TypeTransaction.GAIN, points=10).exists())

    def test_annuler_commande_restores_stock_atomically(self):
        """L'annulation d'une commande restitue immédiatement le stock au dépôt."""
        self.depot.stock_6kg = 8
        self.depot.save()

        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            quantite_6kg=2,
            quantite_12kg=0,
            montant_total=Decimal('7000.00'),
            statut=StatutCommande.EN_ATTENTE,
            adresse_livraison="Bastos",
            latitude_livraison=3.8870,
            longitude_livraison=11.5190,
            code_confirmation="123456"
        )
        url = reverse('commandes:commande_annuler', kwargs={'pk': commande.pk})
        self.client.force_authenticate(user=self.client_user)

        response = self.client.put(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['statut'], StatutCommande.ANNULEE)

        # Stock restitué : 8 + 2 = 10
        self.depot.refresh_from_db()
        self.assertEqual(self.depot.stock_6kg, 10)

    def test_suivi_position_livreur_and_eta(self):
        """Enregistrement GPS du livreur et calcul de distance / ETA."""
        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            livreur=self.livreur_user,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=Decimal('4000.00'),
            statut=StatutCommande.EN_LIVRAISON,
            adresse_livraison="Poste Centrale Yaoundé",
            latitude_livraison=3.8667,
            longitude_livraison=11.5167,
            code_confirmation="123456"
        )
        self.client.force_authenticate(user=self.livreur_user)

        # POST position GPS
        pos_url = reverse('livraisons:livraison_position_update', kwargs={'commande_id': commande.pk})
        pos_res = self.client.post(pos_url, {"latitude": 3.8800, "longitude": 11.5170}, format='json')
        self.assertEqual(pos_res.status_code, status.HTTP_201_CREATED)

        # GET position actuelle & ETA
        eta_url = reverse('livraisons:livraison_position_actuelle', kwargs={'pk': commande.pk})
        self.client.force_authenticate(user=self.client_user)
        eta_res = self.client.get(eta_url)
        self.assertEqual(eta_res.status_code, status.HTTP_200_OK)
        self.assertGreater(eta_res.data['distance_restante_km'], 0)
        self.assertGreaterEqual(eta_res.data['eta_minutes'], 2)

    def test_livreur_flow_complet(self):
        """Tester le flux complet du livreur : missions dispos, acceptation, récupération stock, OTP."""
        # Créer commande non assignée
        commande = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            quantite_6kg=1,
            quantite_12kg=0,
            montant_total=Decimal('4000.00'),
            frais_livraison=Decimal('1000.00'),
            statut=StatutCommande.EN_ATTENTE,
            adresse_livraison="Bastos Yaoundé",
            latitude_livraison=3.8700,
            longitude_livraison=11.5100,
            code_confirmation="998877"
        )

        self.client.force_authenticate(user=self.livreur_user)

        # 1. Lister les missions disponibles
        missions_res = self.client.get('/livreurs/missions/')
        self.assertEqual(missions_res.status_code, status.HTTP_200_OK)
        self.assertTrue(missions_res.data['count'] >= 1)

        # 2. Accepter la mission par le livreur
        accepter_url = reverse('commandes:commande_accepter', kwargs={'pk': commande.pk})
        accepter_res = self.client.put(accepter_url, {}, format='json')
        self.assertEqual(accepter_res.status_code, status.HTTP_200_OK)
        commande.refresh_from_db()
        self.assertEqual(commande.livreur, self.livreur_user)

        # 3. Récupérer le stock au dépôt
        recup_url = reverse('commandes:commande_recuperer_stock', kwargs={'pk': commande.pk})
        recup_res = self.client.post(recup_url, {}, format='json')
        self.assertEqual(recup_res.status_code, status.HTTP_200_OK)
        commande.refresh_from_db()
        self.assertEqual(commande.statut, StatutCommande.EN_LIVRAISON)

        # 4. Confirmer livraison avec code OTP
        confirmer_url = reverse('commandes:commande_confirmer', kwargs={'pk': commande.pk})
        confirmer_res = self.client.put(confirmer_url, {"code_otp": "998877"}, format='json')
        self.assertEqual(confirmer_res.status_code, status.HTTP_200_OK)
        commande.refresh_from_db()
        self.assertEqual(commande.statut, StatutCommande.LIVREE)

        # 5. Consulter le tableau de bord livreur
        tb_res = self.client.get('/livreurs/tableau-de-bord/')
        self.assertEqual(tb_res.status_code, status.HTTP_200_OK)
        self.assertEqual(tb_res.data['missions_jour'], 1)
        self.assertEqual(tb_res.data['revenus_jour'], 1000.0)

        # 6. Toggle disponibilité
        dispo_res = self.client.put('/livreurs/disponibilite/', {"est_disponible": False}, format='json')
        self.assertEqual(dispo_res.status_code, status.HTTP_200_OK)
        self.assertFalse(dispo_res.data['est_disponible'])

        # 7. Historique
        histo_res = self.client.get('/livreurs/historique/')
        self.assertEqual(histo_res.status_code, status.HTTP_200_OK)
        self.assertEqual(histo_res.data['total_missions'], 1)

    def test_daily_analytics_kpi_api(self):
        """Tester l'API GET /admin/analytics/daily/ pour les administrateurs."""
        # Utilisateur normal -> 403 Forbidden
        self.client.force_authenticate(user=self.client_user)
        res_forbidden = self.client.get('/admin/analytics/daily/')
        self.assertEqual(res_forbidden.status_code, status.HTTP_403_FORBIDDEN)

        # Création d'un administrateur
        admin_user = User.objects.create_superuser(
            username='admin_analytics',
            telephone='+237699009900',
            password='Password123!'
        )
        self.client.force_authenticate(user=admin_user)

        res_admin = self.client.get('/admin/analytics/daily/')
        self.assertEqual(res_admin.status_code, status.HTTP_200_OK)
        self.assertIn('commandes_aujourdhui', res_admin.data)
        self.assertIn('chiffre_affaires_aujourdhui', res_admin.data)
        self.assertIn('commissions_gazeo_aujourdhui', res_admin.data)
        self.assertIn('depots_en_rupture', res_admin.data)
        self.assertIn('gerants_kyc_en_attente', res_admin.data)
        self.assertIn('taux_livraison_reussie_7j', res_admin.data)

    def test_surveillance_commandes_bloquees_task(self):
        """Tester la tâche Celery d'alerte pour commandes bloquées > 30 minutes sans livreur."""
        from datetime import timedelta
        from django.utils import timezone
        from commandes.tasks import verifier_commandes_bloquees_task

        # Créer une commande datant de 45 minutes sans livreur
        cmd_bloquee = Commande.objects.create(
            client=self.client_user,
            depot=self.depot,
            quantite_6kg=1,
            montant_total=Decimal('4000.00'),
            frais_livraison=Decimal('1000.00'),
            statut=StatutCommande.EN_ATTENTE,
            adresse_livraison="Bastos Yaoundé",
            latitude_livraison=3.8700,
            longitude_livraison=11.5100,
            code_confirmation="112233"
        )
        Commande.objects.filter(pk=cmd_bloquee.pk).update(
            created_at=timezone.now() - timedelta(minutes=45)
        )

        nb_bloquees = verifier_commandes_bloquees_task()
        self.assertGreaterEqual(nb_bloquees, 1)

    def test_csv_export_actions(self):
        """Tester les fonctions d'export CSV pour les commandes, virements et utilisateurs."""
        from commandes.admin import exporter_commandes_csv
        from paiements.admin import exporter_virements_csv
        from auth_user.admin import exporter_utilisateurs_csv
        from paiements.models import VirementHebdomadaire

        # 1. Export Commandes CSV
        cmd_qs = Commande.objects.all()
        res_cmd = exporter_commandes_csv(None, None, cmd_qs)
        self.assertEqual(res_cmd.status_code, 200)
        self.assertEqual(res_cmd['Content-Type'], 'text/csv; charset=utf-8')
        self.assertIn('commandes_gazeo.csv', res_cmd['Content-Disposition'])

        # 2. Export Utilisateurs CSV
        user_qs = User.objects.all()
        res_user = exporter_utilisateurs_csv(None, None, user_qs)
        self.assertEqual(res_user.status_code, 200)
        self.assertIn('utilisateurs_gazeo.csv', res_user['Content-Disposition'])

        # 3. Export Virements CSV
        virement = VirementHebdomadaire.objects.create(
            gerant=self.gerant_user,
            total_brut=Decimal('50000.00'),
            commission_gazeo=Decimal('750.00'),
            net_a_verser=Decimal('49250.00'),
            periode_debut='2026-10-01',
            periode_fin='2026-10-07'
        )
        res_vir = exporter_virements_csv(None, None, VirementHebdomadaire.objects.filter(pk=virement.pk))
        self.assertEqual(res_vir.status_code, 200)
        self.assertIn('virements_gerants_gazeo.csv', res_vir['Content-Disposition'])


