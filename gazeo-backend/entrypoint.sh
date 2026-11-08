#!/bin/sh

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

# 3. Import initial des dépôts de Yaoundé (si la table est vide)
echo "Initialisation catalogue dépôts Yaoundé..."
python manage.py import_depots || true

# 4. Initialisation du compte Super Administrateur GAZEO
echo "Configuration du compte Super Administrateur..."
python -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
admin_phone = os.environ.get('GAZEO_ADMIN_PHONE', '+237699000000')
admin_pass = os.environ.get('GAZEO_ADMIN_PASSWORD', 'GazeoAdmin2026!')
user, created = User.objects.get_or_create(
    telephone=admin_phone,
    defaults={
        'username': 'admin',
        'email': 'admin@gazeo.cm',
        'role': 'ADMIN',
        'is_staff': True,
        'is_superuser': True,
        'is_verified': True,
    }
)
user.set_password(admin_pass)
user.is_staff = True
user.is_superuser = True
user.role = 'ADMIN'
user.is_verified = True
user.save()
print(f'Compte Administrateur prêt : {admin_phone}')
" || true

# 5. Démarrage Gunicorn
echo "Lancement Gunicorn..."
exec gunicorn config.wsgi:application --config gunicorn.conf.py

