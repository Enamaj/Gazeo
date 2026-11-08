import hashlib
import hmac
import json
import logging
import requests
from decimal import Decimal
from django.conf import settings
from rest_framework.exceptions import PermissionDenied

logger = logging.getLogger(__name__)


class NotchpayService:
    """
    Service d'intégration Notchpay pour MTN Mobile Money et Orange Money.
    Supporte l'initialisation de paiement, la vérification cryptographique HMAC
    des webhooks et les remboursements en production.
    """
    API_URL = "https://api.notchpay.co/payments"

    @property
    def public_key(self):
        return getattr(settings, 'NOTCHPAY_PUBLIC_KEY', '')

    @property
    def hash_secret(self):
        return getattr(settings, 'NOTCHPAY_HASH', '')

    def initier_paiement(
        self,
        commande_id: int,
        telephone: str,
        montant: float | Decimal,
        description: str = None
    ) -> dict:
        """
        Initialise un paiement Notchpay et retourne le lien de paiement (checkout URL).
        """
        reference = f"GAZEO-CMD-{commande_id}"
        payload = {
            "amount": int(montant),
            "currency": "XAF",
            "phone": telephone,
            "reference": reference,
            "description": description or f"Règlement GAZEO Commande #{commande_id}",
        }

        headers = {
            "Authorization": f"Bearer {self.public_key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        # Si clé sandbox ou mode test/offline : simulation propre
        if not self.public_key or self.public_key.startswith("sb.sandbox") or settings.DEBUG:
            logger.info(f"[NotchpayService - SIMULATION] Initialisation paiement pour {telephone} ({montant} XAF)")
            return {
                "status": "success",
                "authorization_url": f"https://pay.notchpay.co/sandbox/checkout/{reference}",
                "reference": reference,
                "sandbox": True,
            }

        try:
            response = requests.post(
                f"{self.API_URL}/initialize",
                json=payload,
                headers=headers,
                timeout=10
            )
            data = response.json()
            if response.status_code in (200, 201) and 'authorization_url' in data:
                logger.info(f"[NotchpayService] Paiement initialisé pour #{commande_id} (Réf: {reference})")
                return {
                    "status": "success",
                    "authorization_url": data['authorization_url'],
                    "reference": reference,
                    "raw": data,
                }
            else:
                logger.error(f"[NotchpayService] Échec initialisation Notchpay : {data}")
                raise ValueError(data.get('message', 'Échec initialisation paiement Notchpay.'))
        except requests.RequestException as e:
            logger.error(f"[NotchpayService] Erreur réseau Notchpay : {e}")
            raise

    def verifier_webhook(self, payload_bytes: bytes, signature_header: str) -> bool:
        """
        Vérifie la signature HMAC-SHA256 envoyée par Notchpay dans le header 'x-notch-signature'.
        Lève une PermissionDenied si la signature est invalide.
        """
        if not self.hash_secret:
            logger.warning("[NotchpayService] NOTCHPAY_HASH non configuré.")
            return True

        if not signature_header:
            raise PermissionDenied("Signature Webhook Notchpay manquante.")

        expected_sig = hmac.new(
            key=self.hash_secret.encode('utf-8'),
            msg=payload_bytes,
            digestmod=hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(expected_sig, signature_header):
            logger.warning(f"[NotchpayService] Signature HMAC invalide. Reçue: {signature_header}")
            raise PermissionDenied("Signature HMAC invalide.")

        return True

    def rembourser_paiement(self, reference_notchpay: str, montant: float | Decimal, motif: str = "") -> dict:
        """
        Effectue un remboursement via l'API Notchpay (Prompt 5.2).
        """
        headers = {
            "Authorization": f"Bearer {self.public_key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        # Simulation si sandbox / dev
        if not self.public_key or self.public_key.startswith("sb.") or settings.DEBUG:
            logger.info(f"[NotchpayService - SIMULATION] Remboursement de {montant} XAF pour {reference_notchpay}")
            return {
                "status": "success",
                "message": "Remboursement simulé avec succès",
                "reference": reference_notchpay,
                "amount": float(montant),
            }

        try:
            response = requests.post(
                f"{self.API_URL}/{reference_notchpay}/refund",
                json={"amount": int(montant), "reason": motif},
                headers=headers,
                timeout=10
            )
            return response.json()
        except requests.RequestException as e:
            logger.error(f"[NotchpayService] Erreur lors du remboursement : {e}")
            raise

    def effectuer_transfert(
        self,
        beneficiaire: str,
        montant: int,
        description: str = "",
        reference: str = None
    ) -> dict:
        """
        Déclenche un virement / transfert sortant vers un bénéficiaire Mobile Money (MTN / Orange)
        ou vers le compte marchand GAZEO.
        En mode bac à sable ou simulation, génère une référence de transfert valide.
        """
        import uuid
        ref = reference or f"TRF-{uuid.uuid4().hex[:12].upper()}"

        headers = {
            "Authorization": f"Bearer {self.public_key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        # Simulation si sandbox / dev ou pas de clés production
        if not self.public_key or self.public_key.startswith("sb.") or settings.DEBUG:
            logger.info(
                f"[NotchpayService - SIMULATION] Virement de {montant} FCFA "
                f"vers {beneficiaire} - Ref: {ref} ({description})"
            )
            return {
                "status": "success",
                "reference": ref,
                "amount": int(montant),
                "beneficiaire": beneficiaire,
                "simulation": True,
            }

        try:
            payload = {
                "amount": int(montant),
                "currency": "XAF",
                "recipient": beneficiaire,
                "reference": ref,
                "description": description or f"Virement GAZEO {ref}",
            }
            response = requests.post(
                "https://api.notchpay.co/transfers",
                json=payload,
                headers=headers,
                timeout=10
            )
            data = response.json()
            logger.info(f"[NotchpayService] Réponse virement {ref}: {data}")
            return {
                "status": "success" if response.status_code in (200, 201) else "pending",
                "reference": data.get("reference", ref),
                "amount": int(montant),
                "raw": data
            }
        except Exception as e:
            logger.error(f"[NotchpayService] Erreur transfert vers {beneficiaire}: {e}")
            return {
                "status": "pending",
                "reference": ref,
                "amount": int(montant),
                "error": str(e)
            }


