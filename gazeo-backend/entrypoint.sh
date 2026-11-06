#!/bin/sh
set -e

echo "=== Démarrage de GAZEO Backend Production ==="

# 1. Activation de l'extension PostGIS sur PostgreSQL (si connecté)
echo "Vérification extension PostGIS..."
python -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()
from django.db import connection
try:
    if 'postgis' in connection.settings_dict.get('ENGINE', ''):
        with connection.cursor() as cursor:
            cursor.execute('CREATE EXTENSION IF NOT EXISTS postgis;')
        print('PostGIS extension vérifiée avec succès.')
except Exception as e:
    print('Note PostGIS (non bloquant) :', e)
" || true

# 2. Exécution des migrations Django
echo "Application des migrations..."
python manage.py migrate --no-input || {
    echo "Attention : échec migrate, démarrage gunicorn en cours..."
}

# 3. Démarrage Gunicorn
echo "Lancement Gunicorn..."
exec gunicorn config.wsgi:application --config gunicorn.conf.py
