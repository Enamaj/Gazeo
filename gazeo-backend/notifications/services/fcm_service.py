import logging
import os
from typing import Dict, List, Optional, Any
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

# Firebase admin imports with safe fallback
try:
    import firebase_admin
    from firebase_admin import credentials, messaging, exceptions
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    logger.warning("firebase-admin n'est pas installé ou inaccessible.")


class FCMService:
    """
    Service centralisé pour la gestion des notifications push via Firebase Cloud Messaging.
    Prend en charge :
    - Multi-appareils (1 utilisateur = n tokens)
    - Nettoyage automatique des tokens invalides (erreur 404 / Unregistered)
    - Notifications dédiées client, gérant et livreur
    - Mode simulation automatique pour le développement et les tests automatisés
    """

    _app_initialized = False

    @classmethod
    def _init_firebase(cls) -> bool:
        if cls._app_initialized:
            return True

        if not FIREBASE_AVAILABLE:
            return False

        cred_path = getattr(settings, 'FIREBASE_CREDENTIALS', None)
        if not cred_path or not os.path.exists(cred_path):
            # Mode simulation si credentials non présents
            logger.info("[FCMService] Aucun fichier credentials Firebase trouvé. Mode simulation actif.")
            return False

        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
            cls._app_initialized = True
            return True
        except Exception as e:
            logger.error(f"[FCMService] Erreur lors de l'initialisation de Firebase: {e}")
            return False

    @classmethod
    def enregistrer_token(cls, user, token: str, device_type: str = 'android'):
        """
        Enregistre ou met à jour le token FCM d'un utilisateur (support multi-appareils).
        """
        from notifications.models import DeviceToken

        if not token:
            return None

        device_token, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                'user': user,
                'device_type': device_type or 'android',
                'is_active': True,
                'updated_at': timezone.now()
            }
        )

        # Maintien de compatibilité avec User.fcm_token
        if user.fcm_token != token:
            user.fcm_token = token
            user.save(update_fields=['fcm_token'])

        logger.info(f"[FCMService] Token enregistré pour {user.telephone} ({device_type})")
        return device_token

    @classmethod
    def supprimer_token(cls, token: str):
        """
        Supprime un token FCM invalide ou expiré (ex: 404 Unregistered).
        """
        from notifications.models import DeviceToken
        from auth_user.models import User

        deleted_count, _ = DeviceToken.objects.filter(token=token).delete()
        User.objects.filter(fcm_token=token).update(fcm_token=None)
        logger.warning(f"[FCMService] Token FCM invalide supprimé: {token[:15]}... ({deleted_count} entrées supprimées)")

    @classmethod
    def envoyer_notification(
        cls,
        user,
        titre: str,
        corps: str,
        data: Optional[Dict[str, Any]] = None,
        sound: str = 'default',
        channel_id: str = 'gazeo_general',
        click_action: Optional[str] = None
    ) -> List[str]:
        """
        Envoie une notification push à tous les appareils actifs de l'utilisateur.
        """
        from notifications.models import DeviceToken, NotificationLog

        if not user:
            return []

        # Convertir toutes les valeurs data en chaînes pour FCM
        clean_data = {}
        if data:
            for k, v in data.items():
                clean_data[str(k)] = str(v)

        tokens = list(
            DeviceToken.objects.filter(user=user, is_active=True).values_list('token', flat=True)
        )
        if not tokens and user.fcm_token:
            tokens = [user.fcm_token]

        if not tokens:
            logger.info(f"[FCMService] Aucun token FCM actif pour {user.telephone}. Envoi annulé.")
            NotificationLog.objects.create(
                user=user,
                titre=titre,
                corps=corps,
                data=clean_data,
                statut='SIMULE',
                message_id="no-token-simulation"
            )
            return []

        firebase_ready = cls._init_firebase()
        message_ids = []

        if not firebase_ready:
            # Mode simulation
            logger.info(f"[FCMService-SIMULATION] Notification à {user.telephone}: '{titre}' - '{corps}' (Tokens: {len(tokens)})")
            msg_id = f"sim-{timezone.now().timestamp()}"
            NotificationLog.objects.create(
                user=user,
                titre=titre,
                corps=corps,
                data=clean_data,
                statut='SIMULE',
                message_id=msg_id
            )
            return [msg_id]

        # Envoi réel via Firebase Admin SDK
        for token in tokens:
            try:
                android_config = messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        sound=sound,
                        channel_id=channel_id,
                        click_action=click_action or 'FLUTTER_NOTIFICATION_CLICK',
                        default_vibrate_timings=True
                    )
                )

                message = messaging.Message(
                    notification=messaging.Notification(
                        title=titre,
                        body=corps
                    ),
                    data=clean_data,
                    token=token,
                    android=android_config
                )

                response = messaging.send(message)
                message_ids.append(response)

                NotificationLog.objects.create(
                    user=user,
                    titre=titre,
                    corps=corps,
                    data=clean_data,
                    statut='ENVOYE',
                    message_id=response
                )
                logger.info(f"[FCMService] Notification envoyée avec succès à {user.telephone}, msg_id={response}")

            except (messaging.UnregisteredError, exceptions.NotFoundError) as e:
                logger.warning(f"[FCMService] Token expiré ou 404 Not Found pour {user.telephone}. Suppression du token: {e}")
                cls.supprimer_token(token)
                NotificationLog.objects.create(
                    user=user,
                    titre=titre,
                    corps=corps,
                    data=clean_data,
                    statut='ECHEC',
                    message_id=f"token-deleted-404: {e}"
                )
            except Exception as e:
                logger.error(f"[FCMService] Erreur lors de l'envoi FCM à {user.telephone}: {e}")
                NotificationLog.objects.create(
                    user=user,
                    titre=titre,
                    corps=corps,
                    data=clean_data,
                    statut='ECHEC',
                    message_id=str(e)[:250]
                )

        return message_ids

    # =========================================================================
    # Notifications spécifiques Client
    # =========================================================================

    @classmethod
    def notifier_commande_confirmee(cls, commande):
        """
        'Commande confirmée par [Dépôt]' + action 'Suivre'
        """
        titre = f"Commande confirmée par {commande.depot.nom}"
        corps = f"Votre commande #{commande.id} a été confirmée. Préparation en cours !"
        data = {
            "type": "COMMANDE_CONFIRMEE",
            "action": "suivre",
            "commande_id": commande.id,
            "route": f"/suivi/{commande.id}"
        }
        return cls.envoyer_notification(
            user=commande.client,
            titre=titre,
            corps=corps,
            data=data,
            click_action="/suivi"
        )

    @classmethod
    def notifier_livreur_en_route(cls, commande, estimation_minutes: int = 20):
        """
        'Livreur en route — arrivée estimée 20 min'
        """
        titre = "Livreur en route !"
        corps = f"Livreur en route — arrivée estimée {estimation_minutes} min"
        data = {
            "type": "LIVREUR_EN_ROUTE",
            "action": "suivre",
            "commande_id": commande.id,
            "eta": estimation_minutes,
            "route": f"/suivi/{commande.id}"
        }
        return cls.envoyer_notification(
            user=commande.client,
            titre=titre,
            corps=corps,
            data=data,
            click_action="/suivi"
        )

    @classmethod
    def notifier_livreur_proche(cls, commande):
        """
        'Livreur à 5 min de chez vous !'
        """
        titre = "Livreur tout proche !"
        corps = "Livreur à 5 min de chez vous !"
        data = {
            "type": "LIVREUR_PROCHE",
            "action": "suivre",
            "commande_id": commande.id,
            "route": f"/suivi/{commande.id}"
        }
        return cls.envoyer_notification(
            user=commande.client,
            titre=titre,
            corps=corps,
            data=data,
            click_action="/suivi"
        )

    @classmethod
    def notifier_demande_notation(cls, commande):
        """
        'Notez votre livraison' + action directe vers notation
        """
        titre = "Notez votre livraison"
        corps = "Votre commande est livrée ! Donnez une note au livreur et au dépôt."
        data = {
            "type": "NOTATION",
            "action": "noter",
            "commande_id": commande.id,
            "depot_id": commande.depot.id,
            "route": f"/notation/{commande.id}"
        }
        return cls.envoyer_notification(
            user=commande.client,
            titre=titre,
            corps=corps,
            data=data,
            click_action="/notation"
        )

    # =========================================================================
    # Notifications spécifiques Gérant
    # =========================================================================

    @classmethod
    def notifier_nouvelle_commande(cls, commande):
        """
        'Nouvelle commande — [X] bouteilles' + son + vibration
        """
        gerant = commande.depot.gerant
        if not gerant:
            return []

        total_bouteilles = commande.quantite_6kg + commande.quantite_12kg
        titre = f"Nouvelle commande — {total_bouteilles} bouteille(s)"
        corps = f"Commande #{commande.id} reçue : {commande.quantite_6kg}x6kg, {commande.quantite_12kg}x12.5kg. Montant: {commande.montant_total} FCFA."
        data = {
            "type": "NOUVELLE_COMMANDE",
            "action": "voir_commande",
            "commande_id": commande.id,
            "route": f"/gerant/commandes/{commande.id}"
        }
        return cls.envoyer_notification(
            user=gerant,
            titre=titre,
            corps=corps,
            data=data,
            sound="commande_alert",
            channel_id="commandes_urgentes_channel"
        )

    @classmethod
    def notifier_stock_faible(cls, depot, type_bouteille: str = "6kg", stock_restant: int = 0):
        """
        'Stock faible — il vous reste [N] bouteilles 6kg'
        """
        gerant = depot.gerant
        if not gerant:
            return []

        titre = "Alerte Stock Faible"
        corps = f"Stock faible — il vous reste {stock_restant} bouteilles {type_bouteille}"
        data = {
            "type": "STOCK_FAIBLE",
            "action": "gerer_stock",
            "depot_id": depot.id,
            "type_bouteille": type_bouteille,
            "stock_restant": stock_restant,
            "route": "/gerant/stock"
        }
        return cls.envoyer_notification(
            user=gerant,
            titre=titre,
            corps=corps,
            data=data,
            channel_id="alertes_stock"
        )

    @classmethod
    def notifier_paiement_recu(cls, paiement):
        """
        'Paiement reçu pour commande #[id]'
        """
        gerant = paiement.commande.depot.gerant
        if not gerant:
            return []

        titre = "Paiement Reçu"
        corps = f"Paiement reçu pour commande #{paiement.commande.id} ({paiement.montant} FCFA)"
        data = {
            "type": "PAIEMENT_RECU",
            "action": "voir_paiement",
            "commande_id": paiement.commande.id,
            "paiement_id": paiement.id,
            "montant": paiement.montant,
            "route": f"/gerant/commandes/{paiement.commande.id}"
        }
        return cls.envoyer_notification(
            user=gerant,
            titre=titre,
            corps=corps,
            data=data
        )

    # =========================================================================
    # Notifications spécifiques Livreur
    # =========================================================================

    @classmethod
    def notifier_nouvelle_mission(cls, livreur, commande):
        """
        'Nouvelle mission disponible dans votre zone'
        """
        titre = "Nouvelle mission disponible"
        corps = f"Nouvelle mission disponible dans votre zone — Dépôt {commande.depot.nom}"
        data = {
            "type": "NOUVELLE_MISSION",
            "action": "voir_mission",
            "commande_id": commande.id,
            "depot_nom": commande.depot.nom,
            "frais_livraison": commande.frais_livraison,
            "route": f"/livreur/missions/{commande.id}"
        }
        return cls.envoyer_notification(
            user=livreur,
            titre=titre,
            corps=corps,
            data=data,
            sound="mission_alert",
            channel_id="missions_channel"
        )

    @classmethod
    def notifier_mission_annulee(cls, livreur, commande):
        """
        'Mission annulée — le client a annulé sa commande'
        """
        if not livreur:
            return []

        titre = "Mission annulée"
        corps = f"Mission annulée — le client a annulé sa commande #{commande.id}"
        data = {
            "type": "MISSION_ANNULEE",
            "action": "liste_missions",
            "commande_id": commande.id,
            "route": "/livreur/missions"
        }
        return cls.envoyer_notification(
            user=livreur,
            titre=titre,
            corps=corps,
            data=data
        )
