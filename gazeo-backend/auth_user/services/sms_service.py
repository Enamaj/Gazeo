import logging
import re
from django.conf import settings
from django.core.cache import cache

try:
    import redis
except ImportError:
    redis = None

try:
    from twilio.rest import Client
    from twilio.base.exceptions import TwilioRestException
except ImportError:
    Client = None
    TwilioRestException = Exception

logger = logging.getLogger(__name__)


class TwilioSMSService:
    """
    Service d'envoi de SMS OTP via Twilio avec rate limiting Redis / Cache.
    Supporte les formats camerounais (+237 6XX XX XX XX) et le mode simulation dev.
    """

    def __init__(self):
        self.twilio_enabled = getattr(settings, 'TWILIO_ENABLED', False)
        self.account_sid = getattr(settings, 'TWILIO_ACCOUNT_SID', '')
        self.auth_token = getattr(settings, 'TWILIO_AUTH_TOKEN', '')
        self.from_phone = getattr(settings, 'TWILIO_PHONE_NUMBER', '')
        self._redis_client = None

        # Tentative d'initialisation du client Redis natif si disponible
        redis_url = getattr(settings, 'REDIS_URL', None)
        if redis and redis_url:
            try:
                self._redis_client = redis.from_url(redis_url, socket_timeout=2)
                self._redis_client.ping()
            except Exception as e:
                logger.debug(f"[TwilioSMSService] Redis non joignable, repli sur Django Cache: {e}")
                self._redis_client = None

    def validate_cameroon_number(self, tel: str) -> str:
        """
        Valide et normalise un numéro camerounais au format +237XXXXXXXXX.
        Accepte: 6XXXXXXXX, +2376XXXXXXXX, 2376XXXXXXXX.
        Lève ValueError si le format est invalide.
        """
        if not tel:
            raise ValueError("Le numéro de téléphone ne peut pas être vide.")

        cleaned = re.sub(r'[\s\-\(\)]', '', str(tel))
        match = re.match(r'^(?:\+?237)?(6[25789]\d{7}|6\d{8})$', cleaned)
        if not match:
            raise ValueError(
                f"Format de numéro camerounais invalide : '{tel}'. Format attendu : (+237) 6XX XX XX XX."
            )

        number_body = match.group(1)
        return f"+237{number_body}"

    # -------------------------------------------------------------
    # Rate Limiting (Redis avec fallback automatique sur Django Cache)
    # -------------------------------------------------------------

    def _cache_get(self, key: str):
        if self._redis_client:
            try:
                val = self._redis_client.get(key)
                return val.decode('utf-8') if val else None
            except Exception:
                pass
        return cache.get(key)

    def _cache_incr(self, key: str, timeout: int = 3600) -> int:
        if self._redis_client:
            try:
                pipe = self._redis_client.pipeline()
                pipe.incr(key)
                pipe.expire(key, timeout)
                results = pipe.execute()
                return int(results[0])
            except Exception:
                pass
        val = cache.get(key)
        if val is None:
            cache.set(key, 1, timeout=timeout)
            return 1
        try:
            new_val = cache.incr(key)
        except Exception:
            new_val = int(val) + 1
            cache.set(key, new_val, timeout=timeout)
        return new_val

    def _cache_set(self, key: str, value, timeout: int = 3600):
        if self._redis_client:
            try:
                self._redis_client.setex(key, timeout, str(value))
                return
            except Exception:
                pass
        cache.set(key, value, timeout=timeout)

    def _cache_delete(self, key: str):
        if self._redis_client:
            try:
                self._redis_client.delete(key)
                return
            except Exception:
                pass
        cache.delete(key)

    def is_number_blocked(self, telephone: str) -> bool:
        """Vérifie si le numéro est temporairement bloqué suite à trop d'échecs."""
        norm_phone = self.validate_cameroon_number(telephone)
        blocked_key = f"gazeo:otp:blocked:{norm_phone}"
        return self._cache_get(blocked_key) is not None

    def check_rate_limit_number(self, telephone: str) -> tuple[bool, str]:
        """
        Vérifie le quota : max 3 OTP par numéro par heure.
        Retourne (is_allowed, message).
        """
        norm_phone = self.validate_cameroon_number(telephone)
        if self.is_number_blocked(norm_phone):
            return False, "Ce numéro est temporairement bloqué pendant 1 heure suite à trop de tentatives infructueuses."

        rate_key = f"gazeo:otp:rate:phone:{norm_phone}"
        attempts = self._cache_incr(rate_key, timeout=3600)
        if attempts > 3:
            return False, "Limite atteinte : maximum 3 codes OTP par heure pour ce numéro."
        return True, ""

    def check_rate_limit_ip(self, ip_address: str) -> tuple[bool, str]:
        """
        Vérifie le quota : max 10 OTP par adresse IP par heure.
        Retourne (is_allowed, message).
        """
        if not ip_address:
            return True, ""
        rate_key = f"gazeo:otp:rate:ip:{ip_address}"
        attempts = self._cache_incr(rate_key, timeout=3600)
        if attempts > 10:
            return False, "Trop de demandes depuis cette adresse IP. Veuillez patienter 1 heure."
        return True, ""

    def record_failed_attempt(self, telephone: str) -> int:
        """
        Enregistre un échec de validation OTP.
        Bloque 1h après 5 tentatives échouées.
        """
        norm_phone = self.validate_cameroon_number(telephone)
        failed_key = f"gazeo:otp:failed:{norm_phone}"
        failures = self._cache_incr(failed_key, timeout=3600)

        if failures >= 5:
            blocked_key = f"gazeo:otp:blocked:{norm_phone}"
            self._cache_set(blocked_key, "1", timeout=3600)
            logger.warning(f"[TwilioSMSService] Numéro {norm_phone} BLOQUÉ pour 1 heure (5 échecs).")

        return failures

    def reset_failed_attempts(self, telephone: str):
        """Réinitialise le compteur d'échecs après validation réussie."""
        norm_phone = self.validate_cameroon_number(telephone)
        self._cache_delete(f"gazeo:otp:failed:{norm_phone}")
        self._cache_delete(f"gazeo:otp:blocked:{norm_phone}")

    # -------------------------------------------------------------
    # Envoi de SMS (Twilio réel ou simulation sécurisée)
    # -------------------------------------------------------------

    def send_sms(self, telephone: str, text_message: str) -> bool:
        """
        Envoie un SMS générique (notifications KYC, commandes, alertes).
        """
        try:
            norm_phone = self.validate_cameroon_number(telephone)
        except ValueError as e:
            logger.error(f"[TwilioSMSService] Numéro invalide pour send_sms: {e}")
            return False

        masked_phone = f"{norm_phone[:6]}****{norm_phone[-2:]}"

        if not self.twilio_enabled or not self.account_sid or not self.auth_token:
            logger.info(f"[TwilioSMSService - SIMULATION] SMS pour {masked_phone} : '{text_message}'")
            return True

        if not Client:
            logger.error("[TwilioSMSService] Package twilio non importable.")
            return False

        try:
            client = Client(self.account_sid, self.auth_token)
            message = client.messages.create(
                body=text_message,
                from_=self.from_phone,
                to=norm_phone
            )
            logger.info(f"[TwilioSMSService] SMS envoyé (SID: {message.sid}) à {masked_phone}")
            return True
        except Exception as e:
            logger.error(f"[TwilioSMSService] Erreur lors de l'envoi SMS : {e}")
            return False

    def send_otp(self, telephone: str, code: str) -> bool:
        """
        Envoie le SMS OTP au format 'Votre code GAZEO : {code}'.
        Retourne False si Twilio est désactivé ou si la livraison échoue.
        """
        norm_phone = self.validate_cameroon_number(telephone)
        message_body = f"Votre code GAZEO : {code}"

        # Masquer le numéro pour les logs de sécurité (ex: +237677****33)
        masked_phone = f"{norm_phone[:6]}****{norm_phone[-2:]}"

        if not self.twilio_enabled or not self.account_sid or not self.auth_token:
            logger.warning(
                "[TwilioSMSService] OTP non envoyé : Twilio est désactivé ou mal configuré "
                "pour %s.",
                masked_phone,
            )
            return False

        if not Client:
            logger.error("[TwilioSMSService] Package twilio non importable.")
            return False

        try:
            client = Client(self.account_sid, self.auth_token)
            message = client.messages.create(
                body=message_body,
                from_=self.from_phone,
                to=norm_phone
            )
            logger.info(f"[TwilioSMSService] SMS Twilio envoyé avec succès (SID: {message.sid}) à {masked_phone}")
            return True
        except TwilioRestException as e:
            logger.error(f"[TwilioSMSService] Erreur Twilio RestException pour {masked_phone} : code={e.code}, msg={e.msg}")
            return False
        except Exception as e:
            logger.error(f"[TwilioSMSService] Erreur inattendue lors de l'envoi SMS : {e}")
            return False
