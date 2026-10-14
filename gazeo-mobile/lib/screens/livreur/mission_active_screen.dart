import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/mission_livreur.dart';
import '../../services/api_service.dart';

class MissionActiveScreen extends StatefulWidget {
  final int commandeId;

  const MissionActiveScreen({super.key, required this.commandeId});

  @override
  State<MissionActiveScreen> createState() => _MissionActiveScreenState();
}

class _MissionActiveScreenState extends State<MissionActiveScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  MissionLivreur? _mission;
  LatLng? _positionLivreur;
  Timer? _positionTimer;

  // Yaoundé par défaut (Poste Centrale)
  final LatLng _yaoundeCentre = const LatLng(3.8667, 11.5167);

  @override
  void initState() {
    super.initState();
    _initialiserMission();
    _demarrerSuiviGPS();
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _initialiserMission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.getLivreurTableauDeBord();
      if (data['mission_active'] != null) {
        _mission = MissionLivreur.fromJson(data['mission_active']);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de charger la mission active.";
          _isLoading = false;
        });
      }
    }
  }

  void _demarrerSuiviGPS() {
    // Émission GPS immédiate
    _mettreAJourPositionGPS();

    // Répétition toutes les 15 secondes
    _positionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _mettreAJourPositionGPS();
    });
  }

  Future<void> _mettreAJourPositionGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        final latLng = LatLng(pos.latitude, pos.longitude);


        if (mounted) {
          setState(() => _positionLivreur = latLng);
        }

        // Envoi au backend
        await _apiService.mettreAJourPosition(widget.commandeId, pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('[MissionActive] Erreur localisation GPS: $e');
    }
  }

  Future<void> _recupererStock() async {
    setState(() => _isActionLoading = true);
    try {
      final res = await _apiService.recupererStock(widget.commandeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bouteilles récupérées ! Rendez-vous à l'adresse du client."),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isActionLoading = false;
          if (_mission != null) {
            _mission = MissionLivreur.fromJson(res['commande']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de la validation du stock au dépôt."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmerLivraison() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir le code OTP à 6 chiffres fourni par le client."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.confirmerLivraison(widget.commandeId, code);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Livraison Réussie !'),
              ],
            ),
            content: const Text(
              'La commande a été confirmée avec succès.\nVos gains pour cette livraison ont été crédités.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/livreur/tableau-de-bord');
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Code OTP invalide. Demandez au client de vérifier son application."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _appelerNumero(String telephone) async {
    final uri = Uri.parse('tel:$telephone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'appeler le $telephone")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Course #${widget.commandeId}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Course #${widget.commandeId}')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _initialiserMission,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final mission = _mission;

    final isEnLivraison = mission?.statut == 'EN_LIVRAISON';

    final depotLocation = (mission?.depotLatitude != null && mission?.depotLongitude != null)
        ? LatLng(mission!.depotLatitude!, mission.depotLongitude!)
        : _yaoundeCentre;

    final clientLocation = (mission != null)
        ? LatLng(mission.latitudeLivraison, mission.longitudeLivraison)
        : _yaoundeCentre;

    return Scaffold(
      appBar: AppBar(
        title: Text('Course #${widget.commandeId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialiserMission,
          ),
        ],
      ),
      body: Column(
        children: [
          // Carte Map avec marqueurs
          Expanded(
            flex: 5,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _positionLivreur ?? depotLocation,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'cm.gazeo.gazeo_mobile',
                ),
                MarkerLayer(
                  markers: [
                    // Marqueur Livreur (Position actuelle)
                    if (_positionLivreur != null)
                      Marker(
                        point: _positionLivreur!,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.two_wheeler, color: Colors.white, size: 24),
                        ),
                      ),
                    // Marqueur Dépôt
                    Marker(
                      point: depotLocation,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 22),
                      ),
                    ),
                    // Marqueur Client
                    Marker(
                      point: clientLocation,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 26),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Panneau d'action de mission
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
              ),
              child: ListView(
                children: [
                  // Étape d'avancement
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEnLivraison ? Colors.orange[100] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEnLivraison ? 'ÉTAPE 2 : EN ROUTE VERS CLIENT' : 'ÉTAPE 1 : RÉCUPÉRATION AU DÉPÔT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isEnLivraison ? Colors.orange[900] : Colors.blue[900],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (mission != null)
                        Text(
                          '${mission.fraisLivraison.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Si étape 1 : Collecte au dépôt
                  if (!isEnLivraison) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1E3A8A),
                        child: Icon(Icons.storefront, color: Colors.white),
                      ),
                      title: Text(mission?.depotNom ?? 'Dépôt'),
                      subtitle: Text(mission?.depotAdresse.isNotEmpty == true ? mission!.depotAdresse : (mission?.depotQuartier ?? '')),
                      trailing: (mission?.depotTelephone.isNotEmpty == true)
                          ? IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () => _appelerNumero(mission!.depotTelephone),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isActionLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_box_outlined),
                        label: const Text('Stock récupéré au dépôt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        onPressed: _isActionLoading ? null : _recupererStock,
                      ),
                    ),
                  ] else ...[
                    // Si étape 2 : Livraison au client & Saisie OTP
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(mission?.clientNom.isNotEmpty == true ? mission!.clientNom : 'Client GAZEO'),
                      subtitle: Text(mission?.adresseLivraison ?? ''),
                      trailing: (mission?.clientTelephone.isNotEmpty == true)
                          ? IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () => _appelerNumero(mission!.clientTelephone),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Code OTP 6 chiffres',
                        hintStyle: const TextStyle(fontSize: 14, letterSpacing: 1, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isActionLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.verified),
                        label: const Text('Confirmer la livraison', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        onPressed: _isActionLoading ? null : _confirmerLivraison,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
