import logging
from typing import Optional
from django.core.cache import cache

logger = logging.getLogger(__name__)

# Durées de mise en cache selon le cahier des charges (Prompt 7.1)
CACHE_TTL_DEPOTS_PROCHES = 120   # 2 minutes (120 secondes)
CACHE_TTL_DEPOT_DETAIL = 300     # 5 minutes (300 secondes)


def get_depots_proches_cache_key(
    lat: float,
    lon: float,
    rayon: float,
    marque: Optional[str] = None,
    stock_uniquement: bool = True,
    quartier: Optional[str] = None
) -> str:
    """
    Génère une clé de cache déterministe pour les recherches de proximité.
    Format : depots_proches_{lat:.3f}_{lon:.3f}_{rayon}_{marque}_{stock}_{quartier}
    """
    marque_key = (marque or 'toutes').lower().strip()
    quartier_key = (quartier or 'tous').lower().strip()
    return f"depots_proches_{lat:.3f}_{lon:.3f}_{int(rayon)}_{marque_key}_{stock_uniquement}_{quartier_key}"


def get_depot_detail_cache_key(depot_id: int) -> str:
    """
    Génère la clé de cache pour la fiche détaillée d'un dépôt.
    """
    return f"depot_detail_{depot_id}"


def invalider_cache_depot(depot_id: Optional[int] = None):
    """
    Invalide le cache de la fiche du dépôt et les résultats de proximité.
    Appelée à chaque mise à jour de stock ou de fiche dépôt.
    """
    try:
        if depot_id:
            key_detail = get_depot_detail_cache_key(depot_id)
            cache.delete(key_detail)

        # Invalidation des caches de proximité (Redis delete_pattern si disponible)
        if hasattr(cache, 'delete_pattern'):
            cache.delete_pattern("gazeo:*depots_proches_*")
            cache.delete_pattern("*depots_proches_*")
        else:
            # Fallback pour backend de test ou LocMemCache
            pass

        logger.info(f"[Cache] Invalidation réussie pour le dépôt #{depot_id}")
    except Exception as e:
        logger.warning(f"[Cache] Erreur lors de l'invalidation cache du dépôt #{depot_id}: {e}")

