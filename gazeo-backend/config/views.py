import logging
from django.db import connection
from django.core.cache import cache
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny

logger = logging.getLogger(__name__)


class HealthCheckView(APIView):
    """
    GET /health/
    Endpoint de diagnostic et de liveness pour Railway, UptimeRobot et load balancers.
    Vérifie la disponibilité de PostgreSQL et de Redis.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        health_status = {
            "status": "healthy",
            "timestamp": timezone.now().isoformat(),
            "services": {
                "database": "unknown",
                "cache": "unknown",
            },
            "version": "1.0.0",
        }

        is_healthy = True

        # 1. Vérification Base de données
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                cursor.fetchone()
            health_status["services"]["database"] = "connected"
        except Exception as db_err:
            logger.warning(f"[HealthCheck] Avertissement base de données : {db_err}")
            health_status["services"]["database"] = f"warning: {str(db_err)}"
            health_status["status"] = "degraded"

        # 2. Vérification Cache / Redis
        try:
            cache.set("gazeo_health_ping", "pong", timeout=10)
            if cache.get("gazeo_health_ping") == "pong":
                health_status["services"]["cache"] = "connected"
            else:
                health_status["services"]["cache"] = "unresponsive"
        except Exception as cache_err:
            logger.warning(f"[HealthCheck] Avertissement cache : {cache_err}")
            health_status["services"]["cache"] = f"warning: {str(cache_err)}"

        # Toujours répondre HTTP 200 pour le liveness probe de Railway
        return Response(health_status, status=status.HTTP_200_OK)

