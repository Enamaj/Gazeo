import logging
import time
from django.core.cache import cache
from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D
from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Depot, StatutKYC
from .permissions import IsGerant, IsOwnerDepot
from .serializers import (
    DepotProcheSerializer,
    DepotDetailSerializer,
    DepotStockUpdateSerializer,
    DepotProfileSerializer,
    AvisPublicSerializer,
)
from .services.cache_service import (
    CACHE_TTL_DEPOTS_PROCHES,
    CACHE_TTL_DEPOT_DETAIL,
    get_depots_proches_cache_key,
    get_depot_detail_cache_key,
    invalider_cache_depot,
)
from notation.models import Avis
from commandes.models import Commande
from commandes.serializers import CommandeGerantSerializer
from auth_user.models import GerantKYC, UserRole

logger = logging.getLogger(__name__)



class DepotsProchesView(APIView):
    """
    GET /depots/proches/?lat=X&lon=Y&rayon=5000&marque=TRADEX&stock_uniquement=true
    Endpoint public de géolocalisation des dépôts autour d'une position GPS (Yaoundé).
    - Requête spatiale ST_DWithin sur l'index GiST
    - Tri par distance croissante
    - Retourne max 20 dépôts
    """
    permission_classes = [AllowAny]

    def get(self, request):
        lat = request.query_params.get('lat')
        lon = request.query_params.get('lon')

        if lat is None or lon is None:
            return Response(
                {"detail": "Les paramètres 'lat' (latitude) et 'lon' (longitude) sont obligatoires."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            latitude = float(lat)
            longitude = float(lon)
        except (ValueError, TypeError):
            return Response(
                {"detail": "Coordonnées géographiques invalides. 'lat' et 'lon' doivent être des nombres."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Rayon en mètres (5000m = 5km par défaut)
        try:
            rayon_metres = float(request.query_params.get('rayon', 5000))
        except (ValueError, TypeError):
            rayon_metres = 5000.0

        # Filtre de stock (True par défaut)
        stock_filter = request.query_params.get('stock_uniquement', 'true').lower() in ('true', '1', 'yes')

        # Filtre optionnel par marque (TRADEX, TOTAL, CAMGAZ, etc.)
        marque = request.query_params.get('marque')

        # Filtre optionnel par quartier
        quartier = request.query_params.get('quartier')

        # Clé de cache déterministe (Prompt 7.1)
        cache_key = get_depots_proches_cache_key(
            lat=latitude,
            lon=longitude,
            rayon=rayon_metres,
            marque=marque,
            stock_uniquement=stock_filter,
            quartier=quartier
        )

        t_start = time.perf_counter()
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            duration_ms = (time.perf_counter() - t_start) * 1000
            logger.info(f"[Cache HIT] /depots/proches/ - {cache_key} ({duration_ms:.2f}ms)")
            resp = Response(cached_data, status=status.HTTP_200_OK)
            resp['X-Cache'] = 'HIT'
            resp['X-Response-Time-ms'] = f"{duration_ms:.2f}"
            return resp

        point_utilisateur = Point(longitude, latitude, srid=4326)

        queryset = Depot.objects.filter(
            est_actif=True,
            localisation__dwithin=(point_utilisateur, D(m=rayon_metres))
        )

        if stock_filter:
            queryset = queryset.filter(Q(stock_6kg__gt=0) | Q(stock_12kg__gt=0))

        if marque:
            queryset = queryset.filter(
                marques_disponibles__icontains=marque
            )

        if quartier:
            queryset = queryset.filter(quartier__icontains=quartier)

        # Annotation de distance et tri croissant
        depots = (
            queryset.annotate(distance=Distance('localisation', point_utilisateur))
            .order_by('distance')[:20]
        )

        serializer = DepotProcheSerializer(depots, many=True)
        response_data = {
            "count": len(serializer.data),
            "rayon_metres": rayon_metres,
            "centre": {
                "latitude": latitude,
                "longitude": longitude
            },
            "depots": serializer.data
        }

        # Mise en cache 2 minutes (120 secondes)
        cache.set(cache_key, response_data, timeout=CACHE_TTL_DEPOTS_PROCHES)
        duration_ms = (time.perf_counter() - t_start) * 1000
        logger.info(f"[Cache MISS] /depots/proches/ - {cache_key} calculé en {duration_ms:.2f}ms")

        resp = Response(response_data, status=status.HTTP_200_OK)
        resp['X-Cache'] = 'MISS'
        resp['X-Response-Time-ms'] = f"{duration_ms:.2f}"
        return resp


class DepotDetailView(APIView):
    """
    GET /depots/{id}/
    Fiche détaillée d'un dépôt avec stocks, prix et notes.
    Mise en cache 5 minutes (300 secondes), invalidé à chaque PUT.
    """
    permission_classes = [AllowAny]

    def get(self, request, pk):
        cache_key = get_depot_detail_cache_key(pk)
        t_start = time.perf_counter()
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            duration_ms = (time.perf_counter() - t_start) * 1000
            logger.info(f"[Cache HIT] /depots/{pk}/ ({duration_ms:.2f}ms)")
            resp = Response(cached_data, status=status.HTTP_200_OK)
            resp['X-Cache'] = 'HIT'
            resp['X-Response-Time-ms'] = f"{duration_ms:.2f}"
            return resp

        try:
            depot = Depot.objects.get(pk=pk, est_actif=True)
        except Depot.DoesNotExist:
            return Response(
                {"detail": "Dépôt introuvable ou inactif."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DepotDetailSerializer(depot)
        cache.set(cache_key, serializer.data, timeout=CACHE_TTL_DEPOT_DETAIL)
        duration_ms = (time.perf_counter() - t_start) * 1000
        logger.info(f"[Cache MISS] /depots/{pk}/ calculé en {duration_ms:.2f}ms")

        resp = Response(serializer.data, status=status.HTTP_200_OK)
        resp['X-Cache'] = 'MISS'
        resp['X-Response-Time-ms'] = f"{duration_ms:.2f}"
        return resp



class DepotAvisListView(APIView):
    """
    GET /depots/{id}/avis/
    Liste des avis clients pour un dépôt spécifique.
    """
    permission_classes = [AllowAny]

    def get(self, request, pk):
        try:
            depot = Depot.objects.get(pk=pk)
        except Depot.DoesNotExist:
            return Response(
                {"detail": "Dépôt introuvable."},
                status=status.HTTP_404_NOT_FOUND
            )

        avis = depot.avis.all().order_by('-created_at')
        serializer = AvisPublicSerializer(avis, many=True)
        return Response({
            "depot_id": pk,
            "depot_nom": depot.nom,
            "count": avis.count(),
            "avis": serializer.data
        }, status=status.HTTP_200_OK)


class GerantMonDepotView(APIView):
    """
    GET /gerants/mon-depot/ — Consulter son dépôt
    PUT /gerants/mon-depot/ — Mettre à jour les informations et prix
    Réservé aux utilisateurs authentifiés avec le rôle GERANT.
    """
    permission_classes = [IsAuthenticated, IsGerant]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_object(self, user):
        depot = Depot.objects.filter(gerant=user).first()
        return depot

    def get(self, request):
        depot = self.get_object(request.user)
        if not depot:
            return Response(
                {"detail": "Aucun dépôt associé à votre compte gérant."},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = DepotDetailSerializer(depot)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        if not request.user.is_verified:
            return Response(
                {"detail": "Vérifiez votre numéro de téléphone avant de configurer le dépôt."},
                status=status.HTTP_403_FORBIDDEN,
            )
        kyc = GerantKYC.objects.filter(gerant=request.user).first()
        if not kyc or kyc.statut != StatutKYC.VALIDE:
            return Response(
                {"detail": "Votre dossier gérant doit être validé avant la création du dépôt."},
                status=status.HTTP_403_FORBIDDEN,
            )
        if self.get_object(request.user):
            return Response(
                {"detail": "Un dépôt est déjà associé à votre compte."},
                status=status.HTTP_409_CONFLICT,
            )

        serializer = DepotProfileSerializer(
            data=request.data,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        depot = serializer.save()
        invalider_cache_depot(depot.id)
        return Response(
            DepotDetailSerializer(depot).data,
            status=status.HTTP_201_CREATED,
        )

    def put(self, request):
        depot = self.get_object(request.user)
        if not depot:
            return Response(
                {"detail": "Aucun dépôt associé à votre compte gérant."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DepotProfileSerializer(depot, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            invalider_cache_depot(depot.id)
            return Response(DepotDetailSerializer(depot).data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class GerantStockUpdateView(APIView):
    """
    POST /gerants/mon-depot/stock/
    Mettre à jour rapidement les stocks de bouteilles 6kg et 12.5kg.
    """
    permission_classes = [IsAuthenticated, IsGerant]

    def post(self, request):
        depot = Depot.objects.filter(gerant=request.user).first()
        if not depot:
            return Response(
                {"detail": "Aucun dépôt associé à votre compte gérant."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DepotStockUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        depot.stock_6kg = serializer.validated_data['stock_6kg']
        depot.stock_12kg = serializer.validated_data['stock_12kg']
        update_fields = ['stock_6kg', 'stock_12kg', 'updated_at']
        if depot.stock_disponible == 0:
            depot.marques_disponibles = []
            update_fields.append('marques_disponibles')
        depot.save(update_fields=update_fields)
        invalider_cache_depot(depot.id)

        return Response({
            "message": "Stock mis à jour avec succès",
            "stock_6kg": depot.stock_6kg,
            "stock_12kg": depot.stock_12kg,
            "stock_disponible": depot.stock_disponible
        }, status=status.HTTP_200_OK)


class GerantNotifierStockView(APIView):
    """Notifie les clients ayant déjà commandé à ce dépôt lors d'un réassort."""

    permission_classes = [IsAuthenticated, IsGerant]

    def post(self, request):
        depot = Depot.objects.filter(gerant=request.user).first()
        if not depot:
            return Response(
                {"detail": "Aucun dépôt associé à votre compte gérant."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if depot.stock_disponible <= 0:
            return Response(
                {"detail": "Ajoutez du stock avant de prévenir vos clients."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not depot.marques_disponibles:
            return Response(
                {"detail": "Indiquez les marques actuellement en stock avant de prévenir vos clients."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from auth_user.models import User
        from notifications.services.fcm_service import FCMService

        clients = User.objects.filter(
            role=UserRole.CLIENT,
            commandes_client__depot=depot,
        ).exclude(
            commandes_client__statut='ANNULEE',
        ).distinct()

        clients_cibles = clients.count()
        notifications_envoyees = 0
        for client in clients.iterator():
            message_ids = FCMService.envoyer_notification(
                user=client,
                titre=f"Le stock est de retour chez {depot.nom}",
                corps=(
                    f"{depot.quartier} : des bouteilles sont de nouveau disponibles. "
                    "Consultez le dépôt dans GAZEO."
                ),
                data={
                    "type": "RETOUR_STOCK",
                    "action": "voir_depot",
                    "depot_id": depot.id,
                    "route": f"/depot/{depot.id}",
                },
                channel_id="alertes_stock",
            )
            notifications_envoyees += sum(
                not message_id.startswith('sim-')
                for message_id in message_ids
            )

        return Response(
            {
                "message": "Notification de retour en stock traitée.",
                "clients_cibles": clients_cibles,
                "notifications_envoyees": notifications_envoyees,
            },
            status=status.HTTP_200_OK,
        )



class GerantCommandesView(APIView):
    """
    GET /gerants/commandes/
    Liste des commandes reçues par le dépôt du gérant connecté.
    Filtre optionnel : ?statut=EN_ATTENTE
    """
    permission_classes = [IsAuthenticated, IsGerant]

    def get(self, request):
        depot = Depot.objects.filter(gerant=request.user).first()
        if not depot:
            return Response(
                {"detail": "Aucun dépôt associé à votre compte gérant."},
                status=status.HTTP_404_NOT_FOUND
            )

        commandes = Commande.objects.filter(depot=depot).order_by('-created_at')
        statut_filtre = request.query_params.get('statut')
        if statut_filtre:
            commandes = commandes.filter(statut=statut_filtre)

        serializer = CommandeGerantSerializer(commandes, many=True)
        return Response({
            "depot_id": depot.id,
            "depot_nom": depot.nom,
            "count": commandes.count(),
            "commandes": serializer.data
        }, status=status.HTTP_200_OK)
