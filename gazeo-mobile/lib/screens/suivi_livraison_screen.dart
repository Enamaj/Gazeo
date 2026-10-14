import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class SuiviLivraisonScreen extends StatefulWidget {
  final int commandeId;
  final String? codeConfirmation;

  const SuiviLivraisonScreen({
    super.key,
    required this.commandeId,
    this.codeConfirmation,
  });

  @override
  State<SuiviLivraisonScreen> createState() => _SuiviLivraisonScreenState();
}

class _SuiviLivraisonScreenState extends State<SuiviLivraisonScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  Timer? _pollingTimer;

  bool _isLoading = true;
  LatLng? _positionLivreur;
  LatLng? _positionDestination;
  String? _adresseDestination;
  double? _distanceRestanteKm;
  int? _etaMinutes;
  String? _livreurTelephone;
  String _statutCommande = 'EN_LIVRAISON';

  @override
  void initState() {
    super.initState();
    _fetchPositionActuelle();
    // Polling régulier toutes les 15 secondes selon spécification Prompt 4.2
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchPositionActuelle(isPolling: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPositionActuelle({bool isPolling = false}) async {
    try {
      final response = await _apiService.dio.get('/livraisons/${widget.commandeId}/position-actuelle/');
      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        final posLivreur = data['position_livreur'];
        final dest = data['destination'];

        setState(() {
          if (posLivreur != null) {
            _positionLivreur = LatLng(
              (posLivreur['latitude'] as num).toDouble(),
              (posLivreur['longitude'] as num).toDouble(),
            );
          }
          if (dest != null) {
            _positionDestination = LatLng(
              (dest['latitude'] as num).toDouble(),
              (dest['longitude'] as num).toDouble(),
            );
            _adresseDestination = dest['adresse'] as String?;
          }
          _distanceRestanteKm = (data['distance_restante_km'] as num?)?.toDouble();
          _etaMinutes = data['eta_minutes'] as int?;
          _statutCommande = data['statut_commande'] ?? _statutCommande;
          _isLoading = false;
        });

        // Recentrer si première récupération
        if (!isPolling && _positionLivreur != null) {
          _mapController.move(_positionLivreur!, 15.0);
        }
      }
    } catch (e) {
      if (mounted && !isPolling) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _appelerLivreur() async {
    final tel = _livreurTelephone ?? '+237600000000';
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _positionLivreur ?? _positionDestination ?? const LatLng(3.8667, 11.5167);

    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi de livraison #${widget.commandeId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchPositionActuelle(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte interactive OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'cm.gazeo.app',
              ),
              MarkerLayer(
                markers: [
                  // Marqueur destination client
                  if (_positionDestination != null)
                    Marker(
                      point: _positionDestination!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[900],
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.home, color: Colors.white, size: 24),
                      ),
                    ),
                  // Marqueur livreur en temps réel
                  if (_positionLivreur != null)
                    Marker(
                      point: _positionLivreur!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: const Icon(Icons.two_wheeler, color: Colors.black87, size: 28),
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (_isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Synchronisation GPS du livreur...'),
                  ),
                ),
              ),
            ),

          // Panneau inférieur d'information et d'actions
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicateur d'avancement
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping, color: Colors.amber, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _etaMinutes != null ? 'Arrivée estimée : ~$_etaMinutes min' : 'Livreur en route',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _distanceRestanteKm != null
                                    ? 'Distance restante : $_distanceRestanteKm km${_adresseDestination != null ? ' • $_adresseDestination' : ''}'
                                    : (_adresseDestination ?? 'Localisation en direct'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Code OTP client à donner au livreur
                    if (widget.codeConfirmation != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Code OTP à donner au livreur :',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              widget.codeConfirmation!,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bouton Appeler le livreur
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _appelerLivreur,
                        icon: const Icon(Icons.phone),
                        label: const Text('Appeler le livreur'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

