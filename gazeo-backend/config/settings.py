"""
Django settings for GAZEO backend.
Configured for production-readiness with django-environ, SimpleJWT, and CORS.
"""

from datetime import timedelta
from pathlib import Path
import environ

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# Initialize environment variables
env = environ.Env(
    DEBUG=(bool, False),
    ALLOWED_HOSTS=(list, ['127.0.0.1', 'localhost']),
    CORS_ALLOWED_ORIGINS=(list, []),
    TWILIO_ENABLED=(bool, False),
)

# Read .env file from gazeo-backend or parent root
env_file = BASE_DIR / '.env'
if not env_file.exists():
    env_file = BASE_DIR.parent / '.env.development'
if env_file.exists():
    environ.Env.read_env(str(env_file))

# Security settings
SECRET_KEY = env('SECRET_KEY', default='django-insecure-gazeo-production-ready-default-key-2026')
DEBUG = env.bool('DEBUG', default=False)
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=['127.0.0.1', 'localhost'])

# Application definition
DJANGO_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',
]

THIRD_PARTY_APPS = [
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'cloudinary_storage',
    'cloudinary',
]

LOCAL_APPS = [
    'auth_user.apps.AuthUserConfig',
    'depots.apps.DepotsConfig',
    'commandes.apps.CommandesConfig',
    'paiements.apps.PaiementsConfig',
    'notation.apps.NotationConfig',
    'fidelite.apps.FideliteConfig',
    'notifications.apps.NotificationsConfig',
]


INSTALLED_APPS = ['jazzmin'] + DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS


MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# Database configuration
DATABASES = {
    'default': env.db('DATABASE_URL', default=f'sqlite:///{BASE_DIR / "db.sqlite3"}')
}
# Automatically use PostGIS backend when PostgreSQL is provided
if 'postgresql' in DATABASES['default']['ENGINE']:
    DATABASES['default']['ENGINE'] = 'django.contrib.gis.db.backends.postgis'


# Custom User Model
AUTH_USER_MODEL = 'auth_user.User'

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Douala'  # Yaoundé timezone (UTC+1)
USE_I18N = True
USE_TZ = True

# Static & Media files
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Django REST Framework settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}

# SimpleJWT configuration
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
}

# CORS settings
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = env.list('CORS_ALLOWED_ORIGINS', default=[])

# External Services configuration
TWILIO_ACCOUNT_SID = env('TWILIO_ACCOUNT_SID', default='')
TWILIO_AUTH_TOKEN = env('TWILIO_AUTH_TOKEN', default='')
TWILIO_PHONE_NUMBER = env('TWILIO_PHONE_NUMBER', default='')
TWILIO_ENABLED = env.bool('TWILIO_ENABLED', default=False)

NOTCHPAY_PUBLIC_KEY = env('NOTCHPAY_PUBLIC_KEY', default='')
NOTCHPAY_HASH = env('NOTCHPAY_HASH', default='')

# Cloudinary configuration (KYC storage)
CLOUDINARY_STORAGE = {
    'CLOUD_NAME': env('CLOUDINARY_CLOUD_NAME', default='gazeo_cloud'),
    'API_KEY': env('CLOUDINARY_API_KEY', default='gazeo_key'),
    'API_SECRET': env('CLOUDINARY_API_SECRET', default='gazeo_secret'),
}

# Firebase Cloud Messaging configuration
FIREBASE_CREDENTIALS = env('FIREBASE_CREDENTIALS', default=None)

# Cache Redis configuration
REDIS_URL = env('REDIS_URL', default='redis://127.0.0.1:6379/1')

def _check_redis(url):
    try:
        import redis
        client = redis.from_url(url, socket_timeout=0.5, socket_connect_timeout=0.5)
        client.ping()
        return True
    except Exception:
        return False

_redis_options = {
    "CLIENT_CLASS": "django_redis.client.DefaultClient",
    "IGNORE_EXCEPTIONS": True,
}

if not _check_redis(REDIS_URL):
    _redis_options["CONNECTION_FACTORY"] = "config.redis_factory.FakeConnectionFactory"

CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": REDIS_URL,
        "OPTIONS": _redis_options,
        "KEY_PREFIX": "gazeo",
        "TIMEOUT": 300,
    }
}

# Celery configuration
CELERY_BROKER_URL = env('CELERY_BROKER_URL', default='redis://127.0.0.1:6379/0')
CELERY_RESULT_BACKEND = env('CELERY_RESULT_BACKEND', default='redis://127.0.0.1:6379/0')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = 'Africa/Douala'
CELERY_TASK_ALWAYS_EAGER = env.bool('CELERY_TASK_ALWAYS_EAGER', default=True)

# Admin Alertes Critiques (Twilio SMS)
ADMIN_PHONE_NUMBER = env('ADMIN_PHONE_NUMBER', default='+237699000000')

# Jazzmin Admin Theme Configuration
JAZZMIN_SETTINGS = {
    "site_title": "GAZEO Admin",
    "site_header": "GAZEO — Administration Yaoundé",
    "site_brand": "GAZEO",
    "welcome_sign": "Bienvenue sur le portail d'administration GAZEO",
    "copyright": "GAZEO Cameroon SARL",
    "search_model": ["auth_user.User", "depots.Depot", "commandes.Commande"],
    "user_avatar": None,
    "topmenu_links": [
        {"name": "Accueil", "url": "admin:index", "permissions": ["auth.view_user"]},
        {"name": "Analytics & KPIs", "url": "/admin/analytics/daily/", "permissions": ["auth.view_user"]},
    ],
    "show_sidebar": True,
    "navigation_expanded": True,
    "icons": {
        "auth_user.User": "fas fa-users",
        "auth_user.GerantKYC": "fas fa-id-card",
        "depots.Depot": "fas fa-store-alt",
        "commandes.Commande": "fas fa-shopping-cart",
        "commandes.SuiviPosition": "fas fa-map-marker-alt",
        "paiements.Paiement": "fas fa-money-bill-wave",
        "paiements.VirementHebdomadaire": "fas fa-file-invoice-dollar",
        "notifications.DeviceToken": "fas fa-mobile-alt",
        "notifications.NotificationLog": "fas fa-bell",
        "notation.Avis": "fas fa-star",
        "fidelite.Transaction": "fas fa-gift",
    },
    "default_icon_parents": "fas fa-chevron-circle-right",
    "default_icon_children": "fas fa-circle",
}

JAZZMIN_UI_TWEAKS = {
    "navbar_small_text": False,
    "footer_small_text": False,
    "body_small_text": False,
    "brand_small_text": False,
    "brand_colour": "navbar-primary",
    "accent": "accent-primary",
    "navbar": "navbar-dark navbar-primary",
    "no_navbar_border": False,
    "navbar_fixed": False,
    "layout_boxed": False,
    "footer_fixed": False,
    "sidebar_fixed": False,
    "sidebar": "sidebar-dark-primary",
    "sidebar_nav_small_text": False,
    "sidebar_disable_expand": False,
    "sidebar_nav_child_indent": True,
    "sidebar_nav_compact_style": False,
    "sidebar_nav_legacy_style": False,
    "sidebar_nav_flat_style": False,
    "theme": "default",
    "dark_mode_theme": None,
    "button_classes": {
        "primary": "btn-primary",
        "secondary": "btn-secondary",
        "info": "btn-info",
        "warning": "btn-warning",
        "danger": "btn-danger",
        "success": "btn-success"
    }
}

# ==============================================================================
# Checklist Sécurité OWASP — Headers et Paramètres de Production
# ==============================================================================
SECURE_SSL_REDIRECT = env.bool('SECURE_SSL_REDIRECT', default=not DEBUG)
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = env.bool('SESSION_COOKIE_SECURE', default=not DEBUG)
CSRF_COOKIE_SECURE = env.bool('CSRF_COOKIE_SECURE', default=not DEBUG)
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# HTTP Strict Transport Security (HSTS)
if not DEBUG:
    SECURE_HSTS_SECONDS = env.int('SECURE_HSTS_SECONDS', default=31536000)
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
else:
    SECURE_HSTS_SECONDS = 0
