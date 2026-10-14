import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../models/depot.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

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
  List<DepotModel> _depots = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userRole;

  // Filtres
  String? _selectedMarque;
  bool _stockUniquement = false;
  double _rayonMetres = 5000;

  final List<String> _marques = ['Toutes', 'TRADEX', 'TOTAL', 'CAMGAZ', 'AUTRE'];

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _initPositionAndFetchDepots();
  }

  Future<void> _checkAuthStatus() async {
    final loggedIn = await _authService.isLoggedIn();
    final role = await _authService.getUserRole();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _userRole = role;
      });
    }
  }


  Future<void> _initPositionAndFetchDepots() async {
    setState(() => _isLoading = true);
    final pos = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() => _currentLocation = pos);
      _mapController.move(pos, 14.0);
      await _fetchDepots();
    }
  }

  Future<void> _fetchDepots() async {
    try {
      final depots = await _apiService.getDepotsProches(
        lat: _currentLocation.latitude,
        lon: _currentLocation.longitude,
        rayon: _rayonMetres,
        marque: _selectedMarque == 'Toutes' ? null : _selectedMarque,
        stockUniquement: _stockUniquement,
        quartier: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _depots = depots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de charger les dépôts : $e')),
        );
      }
    }
  }

  Color _getMarkerColor(DepotModel depot) {
    if (depot.enRupture) return Colors.red;
    if (depot.stockFaible) return Colors.orange;
    return const Color(0xFF10B981); // Vert succès
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.amber),
            SizedBox(width: 8),
            Text('GAZEO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          if (!_isLoggedIn)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Mode invité : invite à la connexion
                  _showAuthDialog();
                },
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Mode invité'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ),
          if (_userRole == 'LIVREUR')

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/livreur/tableau-de-bord'),
                icon: const Icon(Icons.two_wheeler, size: 18),
                label: const Text('Livreur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[400],
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          IconButton(

            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtres',
            onPressed: _showFilterModal,
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
              initialZoom: 14.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'cm.gazeo.app',
              ),
              // Marker de la position actuelle de l'utilisateur
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blueAccent,
                      size: 32,
                    ),
                  ),
                  // Markers des dépôts de gaz
                  ..._depots.map(
                    (depot) => Marker(
                      point: LatLng(depot.latitude, depot.longitude),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => context.push('/depot/${depot.id}'),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _getMarkerColor(depot),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Icon(Icons.propane_tank, color: Colors.white, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Barre de recherche par quartier
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un quartier (Bastos, Melen, etc.)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _fetchDepots();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (_) => _fetchDepots(),
              ),
            ),
          ),

          // Bouton flottant recentrer sur ma position GPS
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps',
              backgroundColor: Colors.white,
              onPressed: _initPositionAndFetchDepots,
              child: const Icon(Icons.my_location, color: Colors.blueAccent),
            ),
          ),

          // Indicateur de chargement
          if (_isLoading)
            const Positioned(
              top: 75,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Recherche des dépôts à Yaoundé...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // BottomSheet glissant avec la liste des dépôts
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.12,
            maxChildSize: 0.65,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dépôts disponibles (${_depots.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rayon : ${(_rayonMetres / 1000).toStringAsFixed(1)} km',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_depots.isEmpty && !_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'Aucun dépôt trouvé dans cette zone.\nEssayez d\'élargir le rayon.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ..._depots.map((depot) => _buildDepotCard(depot)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDepotCard(DepotModel depot) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getMarkerColor(depot).withValues(alpha: 0.15),
          child: Icon(Icons.propane_tank, color: _getMarkerColor(depot)),
        ),
        title: Text(depot.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${depot.quartier} • Marque : ${depot.marque}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMarkerColor(depot).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    depot.enRupture ? 'Rupture' : '${depot.stockDisponible} bouteilles',
                    style: TextStyle(color: _getMarkerColor(depot), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (depot.distanceKm != null)
                  Text('${depot.distanceKm} km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text('${depot.noteMoyenne}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/depot/${depot.id}'),
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtres de recherche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Marque de gaz :'),
                  Wrap(
                    spacing: 8,
                    children: _marques.map((marque) {
                      final selected = (_selectedMarque ?? 'Toutes') == marque;
                      return ChoiceChip(
                        label: Text(marque),
                        selected: selected,
                        onSelected: (val) {
                          setModalState(() => _selectedMarque = val ? marque : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Uniquement dépôts avec stock'),
                    value: _stockUniquement,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setModalState(() => _stockUniquement = val),
                  ),
                  const SizedBox(height: 8),
                  Text('Rayon max : ${(_rayonMetres / 1000).toInt()} km'),
                  Slider(
                    value: _rayonMetres,
                    min: 1000,
                    max: 20000,
                    divisions: 19,
                    label: '${(_rayonMetres / 1000).toInt()} km',
                    onChanged: (val) => setModalState(() => _rayonMetres = val),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                        _fetchDepots();
                      },
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

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bienvenue sur GAZEO'),
        content: const Text(
          'Vous naviguez actuellement en mode invité.\nVous pouvez consulter la carte et les prix sans compte.\nPour commander, connectez-vous ou inscrivez-vous.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continuer en invité')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigation vers écran de connexion ultérieurement
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

