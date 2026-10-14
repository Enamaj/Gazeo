"""
Locust load testing script for GAZEO API.
Simulates 5,000 concurrent users (Clients and Couriers) in Yaoundé, Cameroon.

Usage:
  locust -f locustfile.py --host=http://127.0.0.1:8000 --headless -u 5000 -r 100 --run-time 5m
Target:
  - Median response time < 500ms (< 200ms on cached endpoints)
  - Error rate < 1%
"""

import random
from locust import HttpUser, task, between


_CLIENT_TOKENS = {}
_LIVREUR_TOKENS = {}


class ClientGAZEO(HttpUser):
    """
    Simulation d'un client GAZEO à Yaoundé :
    - 60% consultation de la carte des dépôts proches (PostGIS + Redis cache)
    - 25% consultation de la fiche détaillée d'un dépôt (Redis cache)
    - 10% passation de commande (transaction atomique + déduction de stock)
    - 5% consultation de l'historique de ses commandes
    """
    weight = 10
    wait_time = between(2, 8)

    def on_start(self):
        """Authentification du client GAZEO au démarrage de la session."""
        self.depot_ids = [1, 2, 3]
        self.headers = {"Content-Type": "application/json"}

        # Pool de clients de test générés par seed_load_test_data
        client_num = random.randint(1, 10)
        phone = f"+23769900{client_num:04d}"

        if phone in _CLIENT_TOKENS:
            self.access_token = _CLIENT_TOKENS[phone]
        else:
            login_res = self.client.post(
                "/auth/connexion/",
                json={"telephone": phone, "password": "GazeoTestPass2026!"},
                name="POST /auth/connexion/",
            )
            if login_res.status_code == 200:
                data = login_res.json()
                self.access_token = data.get("tokens", {}).get("access")
                if self.access_token:
                    _CLIENT_TOKENS[phone] = self.access_token
            else:
                self.access_token = None

        if self.access_token:
            self.headers["Authorization"] = f"Bearer {self.access_token}"

    @task(60)
    def voir_carte(self):
        """
        60% du trafic : Recherche des dépôts proches autour d'un point à Yaoundé.
        Endpoint optimisé par PostGIS ST_DWithin + cache Redis (TTL 120s).
        """
        # Yaoundé coordonnées centrales avec légère variation aléatoire
        lat = 3.866 + random.uniform(-0.02, 0.02)
        lon = 11.516 + random.uniform(-0.02, 0.02)
        rayon = random.choice([3000, 5000, 10000])

        with self.client.get(
            f"/depots/proches/?lat={lat:.5f}&lon={lon:.5f}&rayon={rayon}",
            headers=self.headers,
            name="GET /depots/proches/",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                try:
                    depots = response.json().get("depots", [])
                    if depots:
                        self.depot_ids = [d["id"] for d in depots if "id" in d]
                    response.success()
                except Exception:
                    response.success()
            else:
                response.failure(f"Status {response.status_code}: {response.text}")

    @task(25)
    def voir_depot(self):
        """
        25% du trafic : Consultation de la fiche d'un dépôt (détail des stocks et prix).
        Endpoint mis en cache Redis (TTL 300s).
        """
        depot_id = random.choice(self.depot_ids) if self.depot_ids else 1
        with self.client.get(
            f"/depots/{depot_id}/",
            headers=self.headers,
            name="GET /depots/{id}/",
            catch_response=True,
        ) as response:
            if response.status_code in (200, 404):
                response.success()
            else:
                response.failure(f"Status {response.status_code}: {response.text}")

    @task(10)
    def passer_commande(self):
        """
        10% du trafic : Création d'une commande de gaz avec déduction atomique.
        """
        if not self.access_token:
            return

        depot_id = random.choice(self.depot_ids) if self.depot_ids else 1
        payload = {
            "depot_id": depot_id,
            "quantite_6kg": random.choice([0, 1]),
            "quantite_12kg": random.choice([1, 2]),
            "adresse_livraison": f"Quartier Yaoundé Rue {random.randint(100, 999)}",
            "latitude_livraison": round(3.866 + random.uniform(-0.01, 0.01), 5),
            "longitude_livraison": round(11.516 + random.uniform(-0.01, 0.01), 5),
        }

        with self.client.post(
            "/commandes/creer/",
            json=payload,
            headers=self.headers,
            name="POST /commandes/creer/",
            catch_response=True,
        ) as response:
            # 201: Commande créée, 400: Rupture de stock (acceptable sous forte charge concurrente)
            if response.status_code in (201, 400):
                response.success()
            else:
                response.failure(f"Erreur création commande {response.status_code}: {response.text}")

    @task(5)
    def verifier_commande(self):
        """
        5% du trafic : Suivi des commandes du client.
        """
        if not self.access_token:
            return

        with self.client.get(
            "/commandes/mes-commandes/",
            headers=self.headers,
            name="GET /commandes/mes-commandes/",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Status {response.status_code}: {response.text}")


class LivreurGAZEO(HttpUser):
    """
    Simulation d'un coursier / livreur à moto à Yaoundé :
    - 70% consultation des missions disponibles
    - 30% émission de coordonnées GPS en temps réel
    """
    weight = 1
    wait_time = between(5, 12)

    def on_start(self):
        """Authentification du coursier."""
        self.headers = {"Content-Type": "application/json"}

        livreur_num = random.randint(1, 5)
        phone = f"+23767700{livreur_num:04d}"

        if phone in _LIVREUR_TOKENS:
            self.access_token = _LIVREUR_TOKENS[phone]
        else:
            login_res = self.client.post(
                "/auth/connexion/",
                json={"telephone": phone, "password": "GazeoTestPass2026!"},
                name="POST /auth/connexion/ [Livreur]",
            )
            if login_res.status_code == 200:
                data = login_res.json()
                self.access_token = data.get("tokens", {}).get("access")
                if self.access_token:
                    _LIVREUR_TOKENS[phone] = self.access_token
            else:
                self.access_token = None

        if self.access_token:
            self.headers["Authorization"] = f"Bearer {self.access_token}"

    @task(70)
    def voir_missions(self):
        """70% du temps : Consultation des missions disponibles."""
        if not self.access_token:
            return

        with self.client.get(
            "/livreurs/missions/",
            headers=self.headers,
            name="GET /livreurs/missions/",
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Status {response.status_code}: {response.text}")

    @task(30)
    def mettre_a_jour_position(self):
        """30% du temps : Diffusion de la géolocalisation GPS."""
        if not self.access_token:
            return

        payload = {
            "latitude": round(3.866 + random.uniform(-0.03, 0.03), 5),
            "longitude": round(11.516 + random.uniform(-0.03, 0.03), 5),
        }
        with self.client.post(
            "/livraisons/suivi/position/",
            json=payload,
            headers=self.headers,
            name="POST /livraisons/suivi/position/",
            catch_response=True,
        ) as response:
            if response.status_code in (200, 201):
                response.success()
            else:
                response.failure(f"Status {response.status_code}: {response.text}")

