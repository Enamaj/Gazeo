from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D
from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Depot, StatutKYC
from .permissions import IsGerant, IsOwnerDepot
from .serializers import (
    DepotProcheSerializer,
    DepotDetailSerializer,
    DepotUpdateSerializer,
    DepotStockUpdateSerializer,
    AvisPublicSerializer,
)
from notation.models import Avis
from commandes.models import Commande
from commandes.serializers import CommandeGerantSerializer


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

        point_utilisateur = Point(longitude, latitude, srid=4326)

        queryset = Depot.objects.filter(
            est_actif=True,
            localisation__dwithin=(point_utilisateur, D(m=rayon_metres))
        )

        if stock_filter:
            queryset = queryset.filter(Q(stock_6kg__gt=0) | Q(stock_12kg__gt=0))

        if marque:
            queryset = queryset.filter(marque__iexact=marque)

        if quartier:
            queryset = queryset.filter(quartier__icontains=quartier)

        # Annotation de distance et tri croissant
        depots = (
            queryset.annotate(distance=Distance('localisation', point_utilisateur))
            .order_by('distance')[:20]
        )

        serializer = DepotProcheSerializer(depots, many=True)
        return Response({
            "count": len(serializer.data),
            "rayon_metres": rayon_metres,
            "centre": {
                "latitude": latitude,
                "longitude": longitude
            },
            "depots": serializer.data
        }, status=status.HTTP_200_OK)


class DepotDetailView(APIView):
    """
    GET /depots/{id}/
    Fiche détaillée d'un dépôt avec stocks, prix et notes.
    """
    permission_classes = [AllowAny]

    def get(self, request, pk):
        try:
            depot = Depot.objects.get(pk=pk, est_actif=True)
        except Depot.DoesNotExist:
            return Response(
                {"detail": "Dépôt introuvable ou inactif."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DepotDetailSerializer(depot)
        return Response(serializer.data, status=status.HTTP_200_OK)


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

    def put(self, request):
        depot = self.get_object(request.user)
        if not depot:
            return Response(
                {"detail": "Aucun dépôt associé à votre compte gérant."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DepotUpdateSerializer(depot, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
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
        depot.save(update_fields=['stock_6kg', 'stock_12kg', 'updated_at'])

        return Response({
            "message": "Stock mis à jour avec succès",
            "stock_6kg": depot.stock_6kg,
            "stock_12kg": depot.stock_12kg,
            "stock_disponible": depot.stock_disponible
        }, status=status.HTTP_200_OK)


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
