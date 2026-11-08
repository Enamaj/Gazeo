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
            health_status["services"]["database"] = f"connected ({connection.vendor})"
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


from django.http import HttpResponse

class MigrateView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        from io import StringIO
        from django.core.management import call_command
        import traceback

        out = StringIO()
        err = StringIO()
        try:
            # 1. Vérification / Activation PostGIS
            try:
                with connection.cursor() as cursor:
                    cursor.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
                out.write("PostGIS extension vérifiée.\n")
            except Exception as e:
                out.write(f"PostGIS info: {e}\n")

            # 2. Exécution des migrations
            call_command('migrate', stdout=out, stderr=err, interactive=False)

            # 3. Import des dépôts de Yaoundé
            try:
                call_command('import_depots', stdout=out, stderr=err)
            except Exception as e:
                out.write(f"Import depots info: {e}\n")

            # 4. Création Superuser
            from django.contrib.auth import get_user_model
            User = get_user_model()
            u = User.objects.filter(telephone='+237699000000').first() or User.objects.filter(username='admin').first()
            if not u:
                u = User(telephone='+237699000000', username='admin', email='admin@gazeo.cm')
            u.telephone = '+237699000000'
            u.username = 'admin'
            u.set_password('GazeoAdmin2026!')
            u.is_staff = True
            u.is_superuser = True
            u.role = 'ADMIN'
            u.is_verified = True
            u.is_active = True
            u.save()
            out.write("\nCompte Super Administrateur prêt : +237699000000 / GazeoAdmin2026!\n")

            return HttpResponse(
                f"=== GAZEO DATABASE INITIALIZATION SUCCESS ===\n\nSTDOUT:\n{out.getvalue()}\n\nSTDERR:\n{err.getvalue()}",
                content_type="text/plain; charset=utf-8"
            )
        except Exception as e:
            trace = traceback.format_exc()
            return HttpResponse(
                f"=== GAZEO DATABASE INITIALIZATION FAILED ===\n\nError: {e}\n\nTraceback:\n{trace}\n\nSTDOUT:\n{out.getvalue()}\n\nSTDERR:\n{err.getvalue()}",
                content_type="text/plain; charset=utf-8",
                status=500
            )


def custom_error_500(request):
    import sys, traceback
    exc_type, exc_value, exc_traceback = sys.exc_info()
    trace = "".join(traceback.format_exception(exc_type, exc_value, exc_traceback)) if exc_value else "No exception context."
    logger.error(f"[GAZEO 500 ERROR]\n{trace}")
    return HttpResponse(
        f"GAZEO 500 SERVER ERROR:\n\n{trace}",
        content_type="text/plain; charset=utf-8",
        status=500
    )

