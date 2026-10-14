import os
from celery import Celery

# Définir le module de configuration Django par défaut
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('gazeo')

# Charger la configuration depuis les settings Django avec le préfixe CELERY_
app.config_from_object('django.conf:settings', namespace='CELERY')

# Découverte automatique des tâches dans tous les packages installed_apps
app.autodiscover_tasks()


@app.task(bind=True)
def debug_task(self):
    print(f'Celery task request: {self.request!r}')

