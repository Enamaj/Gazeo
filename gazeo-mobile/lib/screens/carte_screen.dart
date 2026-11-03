import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/depot.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_bottom_nav.dart';

class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});

  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  LatLng _currentLocation = LocationService.defaultYaounde;
  bool _hasGpsLocation = false;
  String? _locationMessage;
  List<DepotModel> _depots = [];
  bool _isLoading = true;
  String? _depotsError;
  bool _isLoggedIn = false;
  String? _userRole;
  String? _userPhone;

  // Itinéraire actif
  RouteResult? _activeRoute;
  DepotModel? _selectedDepotForRoute;
  bool _isLoadingRoute = false;

  // Filtres
  String? _selectedMarque;
  String _selectedCategory = 'Tous';
  bool _stockUniquement = false;
  double _rayonMetres = 6000;

  final List<String> _marques = ['Toutes', 'TRADEX', 'TOTAL', 'CAMGAZ', 'SCTM'];

  List<DepotModel> get _filteredDepots {
    return _depots.where((depot) {
      if (_selectedCategory == 'Bouteilles') {
        return depot.stock6kg > 0 || depot.stock12kg > 0 || depot.stockDisponible > 0;
      } else if (_selectedCategory == 'Grandes') {
        return depot.stock12kg > 0 || depot.stockDisponible >= 8;
      } else if (_selectedCategory == 'Accessoires') {
        return depot.estActif;
      }
      return true; // 'Tous'
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _initPositionAndFetchDepots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final loggedIn = await _authService.isLoggedIn();
    final role = await _authService.getUserRole();
    final phone = await _authService.getUserPhone();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _userRole = role;
        _userPhone = phone;
      });
    }
  }

  Future<void> _initPositionAndFetchDepots({LatLng? specificLocation}) async {
    setState(() => _isLoading = true);
    var hasGpsLocation = specificLocation == null;
    String? locationMessage;
    LatLng pos;
    try {
      pos = specificLocation ?? await LocationService.getCurrentPosition();
    } on StateError catch (error) {
      pos = LocationService.defaultYaounde;
      hasGpsLocation = false;
      locationMessage = error.message.toString();
    }
    if (mounted) {
      setState(() {
        _currentLocation = pos;
        _hasGpsLocation = hasGpsLocation;
        _locationMessage = locationMessage;
      });
      _mapController.move(pos, 14.2);
      await _fetchDepots();
      if (locationMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$locationMessage Recherche centrée sur Yaoundé.'),
          ),
        );
      }
    }
  }

  Future<void> _fetchDepots() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _depotsError = null;
      });
    }
    try {
      final depots = await _apiService.getDepotsProches(
        lat: _currentLocation.latitude,
        lon: _currentLocation.longitude,
        rayon: _rayonMetres,
        marque: _selectedMarque == 'Toutes' ? null : _selectedMarque,
        stockUniquement: _stockUniquement,
        quartier: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _depots = depots;
          _isLoading = false;
          _depotsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _depotsError =
              'Impossible de charger les dépôts. Vérifiez votre connexion.';
          _isLoading = false;
        });
        if (kDebugMode) {
          debugPrint('[CarteScreen] Erreur chargement dépôts : $e');
        }
      }
    }
  }

  // =========================================================================
  // Calcul et Affichage de l'Itinéraire
  // =========================================================================

  Future<void> _tracerItineraire(DepotModel depot) async {
    setState(() {
      _isLoadingRoute = true;
      _selectedDepotForRoute = depot;
    });

    final destination = LatLng(depot.latitude, depot.longitude);
    late final RouteResult route;
    try {
      route = await RoutingService.getRoute(
        start: _currentLocation,
        destination: destination,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedDepotForRoute = null;
        _isLoadingRoute = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
      return;
    }

    if (mounted) {
      setState(() {
        _activeRoute = route;
        _isLoadingRoute = false;
      });

      // Recentrer la caméra pour encadrer le départ et l'arrivée
      final midLat = (_currentLocation.latitude + destination.latitude) / 2;
      final midLon = (_currentLocation.longitude + destination.longitude) / 2;
      _mapController.move(LatLng(midLat, midLon), 14.0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0A192F),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.directions_bike, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Itinéraire routier vers ${depot.nom} : ${route.formattedDistance} (~${route.formattedDuration})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _fermerItineraire() {
    setState(() {
      _activeRoute = null;
      _selectedDepotForRoute = null;
    });
  }

  Future<void> _ouvrirGpsExterne(DepotModel depot) async {
    final lat = depot.latitude;
    final lon = depot.longitude;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir l\'application GPS.')),
        );
      }
    }
  }

  // =========================================================================
  // Couleurs et Thème des Marques
  // =========================================================================

  Color _getMarqueColor(String marque) {
    final m = marque.toUpperCase();
    if (m.contains('TOTAL')) {
      return const Color(0xFFE11D48); // Rouge vif TotalEnergies
    }
    if (m.contains('TRADEX')) return const Color(0xFFD97706); // Or ambré Tradex
    if (m.contains('CAMGAZ')) return const Color(0xFF059669); // Vert Camgaz
    if (m.contains('SCTM')) return const Color(0xFF0284C7); // Bleu ciel SCTM
    return const Color(0xFF7C3AED); // Violet
  }

  Color _getStockColor(DepotModel depot) {
    if (depot.enRupture) return const Color(0xFFEF4444);
    if (depot.stockFaible) return const Color(0xFFF59E0B);
    return const Color(0xFF0F766E);
  }

  // =========================================================================
  // Gestion de Profil & Changement de Compte
  // =========================================================================

  void _showAccountDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1D4ED8)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    _isLoggedIn
                        ? (_userRole == 'LIVREUR'
                              ? Icons.two_wheeler
                              : _userRole == 'GERANT'
                              ? Icons.storefront
                              : Icons.person)
                        : Icons.person_outline,
                    color: const Color(0xFF1D4ED8),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoggedIn
                            ? (_userPhone ?? 'Utilisateur GAZEO')
                            : 'Mode Invité',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _isLoggedIn
                              ? const Color(0xFFEFF6FF)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isLoggedIn
                              ? 'Rôle : ${_userRole ?? 'CLIENT'}'
                              : 'Consultation carte libre',
                          style: TextStyle(
                            color: _isLoggedIn
                                ? const Color(0xFF1D4ED8)
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Bouton Changer de compte / Se connecter
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/connexion').then((_) => _checkAuthStatus());
              },
              icon: const Icon(Icons.swap_horiz),
              label: Text(
                _isLoggedIn
                    ? 'Changer de compte'
                    : 'Se connecter / S\'inscrire',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_isLoggedIn && _userRole == 'LIVREUR') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/livreur/tableau-de-bord');
                },
                icon: const Icon(Icons.two_wheeler),
                label: const Text('Espace Livreur (Missions & Gains)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            if (_isLoggedIn && _userRole == 'GERANT') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/gerant/tableau-de-bord');
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Gérer mon dépôt'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            if (_isLoggedIn) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _apiService.deconnexion();
                  await _checkAuthStatus();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Déconnexion effectuée. Vous êtes en mode invité.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Sélecteur de Quartier Rapide de Yaoundé
  // =========================================================================

  void _showYaoundeHubsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.location_city, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 8),
                  Text(
                    'Centrer sur un quartier de Yaoundé',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LocationService.yaoundeHubs.entries.map((entry) {
                  return ActionChip(
                    avatar: const Icon(
                      Icons.place,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    backgroundColor: AppColors.blue50,
                    side: const BorderSide(color: AppColors.blue100),
                    label: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate800,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      LocationService.setForcedLocation(entry.value);
                      _initPositionAndFetchDepots(specificLocation: entry.value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📍 Carte centrée sur ${entry.key}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    LocationService.setForcedLocation(null);
                    _initPositionAndFetchDepots();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📍 Mode GPS automatique restauré.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  label: const Text(
                    'Restaurer GPS par défaut',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: InkWell(
          onTap: _showYaoundeHubsSheet,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.location_on, color: AppColors.primary, size: 20),
                SizedBox(width: 4),
                Text(
                  'Yaoundé',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate600, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.slate700),
            tooltip: 'Filtres & Rayon',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: Icon(
              _isLoggedIn ? Icons.account_circle : Icons.person_outline_rounded,
              color: AppColors.slate700,
            ),
            tooltip: 'Mon Compte',
            onPressed: _showAccountDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte interactive OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.2,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'cm.gazeo.app',
              ),

              // Tracé de l'itinéraire routier actif
              if (_activeRoute != null && _activeRoute!.points.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Halo extérieur pour relief et contraste
                    Polyline(
                      points: _activeRoute!.points,
                      color: const Color(0xFF0A192F).withValues(alpha: 0.35),
                      strokeWidth: 8.0,
                    ),
                    // Ligne principale vive orange flamme GAZEO
                    Polyline(
                      points: _activeRoute!.points,
                      color: const Color(0xFF1D4ED8),
                      strokeWidth: 4.5,
                    ),
                  ],
                ),

              // Couche de Markers
              MarkerLayer(
                markers: [
                  // Position Utilisateur : Balise animée avec anneau pulsé
                  if (_hasGpsLocation)
                    Marker(
                      point: _currentLocation,
                      width: 52,
                      height: 52,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1D4ED8)
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1D4ED8),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Destination de l'itinéraire (Drapeau d'arrivée)
                  if (_selectedDepotForRoute != null)
                    Marker(
                      point: LatLng(
                        _selectedDepotForRoute!.latitude,
                        _selectedDepotForRoute!.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.sports_score,
                        color: Color(0xFF0A192F),
                        size: 32,
                      ),
                    ),

                  // Markers personnalisés des Dépôts de Gaz
                  ..._filteredDepots.map((depot) => _buildDepotMarker(depot)),
                ],
              ),
            ],
          ),

          // Barre de recherche par quartier
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher (Bastos, Melen, Omnisports...)',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1D4ED8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _fetchDepots();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) => _fetchDepots(),
              ),
            ),
          ),

          // Bannière Flottante Itinéraire Actif
          if (_activeRoute != null && _selectedDepotForRoute != null)
            Positioned(
              top: 76,
              left: 14,
              right: 14,
              child: Card(
                elevation: 6,
                color: const Color(0xFF0A192F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.directions_bike,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedDepotForRoute!.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _activeRoute!.formattedDistance,
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ~${_activeRoute!.formattedDuration}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        tooltip: 'Ouvrir GPS externe',
                        onPressed: () =>
                            _ouvrirGpsExterne(_selectedDepotForRoute!),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Fermer itinéraire',
                        onPressed: _fermerItineraire,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Boutons Flottants latéraux (Voir la liste, Hubs Yaoundé & Recentrage GPS)
          Positioned(
            right: 16,
            bottom: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bouton "Voir la liste" conforme à l'écran 4 de la maquette
                ElevatedButton.icon(
                  onPressed: () => context.push('/depots'),
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                  label: const Text(
                    'Voir la liste',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 10),
                // Bouton Sélecteur Quartiers Yaoundé
                FloatingActionButton.small(
                  heroTag: 'yaounde_hubs',
                  backgroundColor: Colors.white,
                  tooltip: 'Quartiers de Yaoundé',
                  onPressed: _showYaoundeHubsSheet,
                  child: const Icon(
                    Icons.location_city,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 8),
                // Bouton Recentrer GPS
                FloatingActionButton.small(
                  heroTag: 'recenter_gps',
                  backgroundColor: AppColors.primary,
                  tooltip: 'Recentrer sur ma position',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    LocationService.setForcedLocation(null);
                    await _initPositionAndFetchDepots();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          _locationMessage == null
                              ? 'Position GPS actualisée.'
                              : 'GPS indisponible. Recherche centrée sur Yaoundé.',
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),

          // Indicateur de chargement
          if (_isLoading || _isLoadingRoute)
            Positioned(
              top: 76,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  color: const Color(0xFF0A192F),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Color(0xFF1D4ED8),
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isLoadingRoute
                              ? 'Calcul de l\'itinéraire...'
                              : 'Recherche des dépôts à Yaoundé...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // BottomSheet glissant avec la liste des dépôts
          DraggableScrollableSheet(
            initialChildSize: 0.24,
            minChildSize: 0.12,
            maxChildSize: 0.70,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Catégories horizontales conformes à l'écran 4 de la maquette
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryFilterChip('Tous'),
                          const SizedBox(width: 8),
                          _buildCategoryFilterChip('Bouteilles'),
                          const SizedBox(width: 8),
                          _buildCategoryFilterChip('Grandes'),
                          const SizedBox(width: 8),
                          _buildCategoryFilterChip('Accessoires'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dépôts disponibles (${_filteredDepots.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Rayon : ${(_rayonMetres / 1000).toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_depotsError != null && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 36,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(_depotsError!, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _fetchDepots,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    if (_filteredDepots.isEmpty && !_isLoading && _depotsError == null)
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedCategory == 'Tous'
                                    ? 'Aucun dépôt trouvé dans ce secteur.\nÉlargissez le rayon ou changez de quartier.'
                                    : 'Aucun dépôt avec l\'option "$_selectedCategory" dans ce secteur.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ..._filteredDepots.map((depot) => _buildDepotCard(depot)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const GazeoBottomNav(currentIndex: 0, role: GazeoNavRole.client),
    );
  }

  Widget _buildCategoryFilterChip(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.slate700,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Marker Stylisé sur la Carte
  // =========================================================================

  Marker _buildDepotMarker(DepotModel depot) {
    final marqueColor = _getMarqueColor(depot.marque);
    final stockColor = _getStockColor(depot);
    final isSelected = _selectedDepotForRoute?.id == depot.id;

    return Marker(
      point: LatLng(depot.latitude, depot.longitude),
      width: 72,
      height: 72,
      child: GestureDetector(
        // Clic sur un dépôt de la carte redirige DIRECTEMENT vers la boutique du vendeur
        onTap: () => context.push('/depot/${depot.id}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bulle Prix flottante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '${depot.prix12kg.toInt()} F',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Pin de marque avec indicateur de stock
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: marqueColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: stockColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: marqueColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      depot.marqueAbregee,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                // Pastille statut stock
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Carte du Dépôt dans le BottomSheet (Clic direct vers Boutique Vendeur)
  // =========================================================================

  Widget _buildDepotCard(DepotModel depot) {
    final marqueColor = _getMarqueColor(depot.marque);
    final stockColor = _getStockColor(depot);
    final isSelectedForRoute = _selectedDepotForRoute?.id == depot.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          Card(
            margin: EdgeInsets.zero,
            elevation: isSelectedForRoute ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelectedForRoute
                    ? const Color(0xFF0F766E)
                    : Colors.grey.shade200,
                width: isSelectedForRoute ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/depot/${depot.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: marqueColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: marqueColor.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: depot.imageDepotUrl != null
                          ? Image.network(
                              depot.imageDepotUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Text(
                                      depot.marqueAbregee,
                                      style: TextStyle(
                                        color: marqueColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                            )
                          : Center(
                              child: Text(
                                depot.marqueAbregee,
                                style: TextStyle(
                                  color: marqueColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  depot.nom,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${depot.noteMoyenne}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${depot.quartier} • ${depot.marquesDisponibles.isEmpty ? 'Aucune marque en stock' : depot.marquesDisponibles.map(_libelleMarque).join(', ')}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: stockColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  depot.enRupture
                                      ? 'Rupture'
                                      : '${depot.stockDisponible} btl en stock',
                                  style: TextStyle(
                                    color: stockColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (depot.distanceKm != null)
                                Text(
                                  '${depot.distanceKm} km',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                depot.formattedPrix12kg,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isSelectedForRoute
                                ? Icons.check_circle
                                : Icons.directions,
                            color: isSelectedForRoute
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF1D4ED8),
                            size: 22,
                          ),
                          tooltip: 'Itinéraire sur la carte',
                          onPressed: () => _tracerItineraire(depot),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: stockColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: stockColor,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _libelleMarque(String marque) => switch (marque.toUpperCase()) {
    'TRADEX' => 'Tradex',
    'SCTM' => 'SCTM',
    'TOTAL' => 'TotalEnergies',
    'CAMGAZ' => 'Camgaz',
    'AUTRE' => 'Autre',
    _ => marque,
  };

  // =========================================================================
  // Modal de Filtres
  // =========================================================================

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtres de recherche',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Marque de gaz :'),
                  Wrap(
                    spacing: 8,
                    children: _marques.map((marque) {
                      final selected = (_selectedMarque ?? 'Toutes') == marque;
                      return ChoiceChip(
                        label: Text(marque),
                        selected: selected,
                        selectedColor: const Color(0xFF1D4ED8),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          setModalState(
                            () => _selectedMarque = val ? marque : null,
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Uniquement dépôts avec stock'),
                    value: _stockUniquement,
                    activeTrackColor: const Color(0xFF1D4ED8),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) =>
                        setModalState(() => _stockUniquement = val),
                  ),
                  const SizedBox(height: 8),
                  Text('Rayon max : ${(_rayonMetres / 1000).toInt()} km'),
                  Slider(
                    value: _rayonMetres,
                    min: 1000,
                    max: 20000,
                    divisions: 19,
                    activeColor: const Color(0xFF1D4ED8),
                    label: '${(_rayonMetres / 1000).toInt()} km',
                    onChanged: (val) => setModalState(() => _rayonMetres = val),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                        _fetchDepots();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Appliquer les filtres'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
