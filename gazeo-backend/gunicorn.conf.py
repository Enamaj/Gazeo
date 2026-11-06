import os
import multiprocessing

# Configuration Gunicorn pour environnement de production GAZEO (Railway Pro)
port = os.getenv("PORT", "8000")
# Écouter simultanément sur le port dynamique Railway ($PORT), sur 8080 et sur 8000 pour éliminer tout risque de 502
bind = list({f"0.0.0.0:{port}", "0.0.0.0:8000", "0.0.0.0:8080"})

# 4 workers par défaut pour Railway Pro
workers = int(os.getenv("WEB_CONCURRENCY", "4"))
threads = int(os.getenv("GUNICORN_THREADS", "2"))
worker_class = "gthread"

# Gestion des connexions et délais d'attente
timeout = 60
keepalive = 5
max_requests = 1000
max_requests_jitter = 50

# Logs dirigés vers stdout/stderr pour Railway / Datadog
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info")
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)sµs'

