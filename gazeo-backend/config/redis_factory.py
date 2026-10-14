import fakeredis
from django_redis.pool import ConnectionFactory

# Serveur mémoire partagé simulant une instance Redis locale/test
_shared_fake_server = fakeredis.FakeServer()


class FakeConnectionFactory(ConnectionFactory):
    """
    Factory de connexion pour django-redis utilisant fakeredis
    lorsque l'instance Redis n'est pas démarrée (tests unitaires ou dev local).
    """
    def get_connection(self, params):
        return fakeredis.FakeRedis(server=_shared_fake_server)

