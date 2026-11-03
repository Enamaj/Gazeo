import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

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
  final MapController _mapController = MapController();
  Timer? _timer;

  // Coordonnées de simulation Yaoundé (Mvog-Ada vers Bastos)
  final LatLng _depotPos = const LatLng(3.8680, 11.5200);
  final LatLng _clientPos = const LatLng(3.8760, 11.5120);
  LatLng _livreurPos = const LatLng(3.8715, 11.5165);

  final List<LatLng> _routePoints = const [
    LatLng(3.8680, 11.5200),
    LatLng(3.8695, 11.5185),
    LatLng(3.8715, 11.5165),
    LatLng(3.8740, 11.5140),
    LatLng(3.8760, 11.5120),
  ];

  @override
  void initState() {
    super.initState();
    // Animation légère de déplacement du livreur
    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (mounted) {
        setState(() {
          _livreurPos = LatLng(
            _livreurPos.latitude + 0.0005,
            _livreurPos.longitude - 0.0004,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate900),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Suivi de votre commande',
          style: TextStyle(
            color: AppColors.slate900,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Carte en direct avec itinéraire et moto en temps réel
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _livreurPos,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'cm.gazeo.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primaryLight,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Point de départ (Dépôt)
                    Marker(
                      point: _depotPos,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 16),
                      ),
                    ),
                    // Destination Client
                    Marker(
                      point: _clientPos,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                      ),
                    ),
                    // Moto Livreur en direct
                    Marker(
                      point: _livreurPos,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.two_wheeler, color: AppColors.primary, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Fiche Livreur & Progression
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte du Livreur
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Container(
                            width: 48,
                            height: 48,
                            color: AppColors.slate100,
                            child: Image.asset(
                              'assets/images/driver_avatar.png',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yao Patrick',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const Text(
                                'Livreur - Moto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                              ),
                              Row(
                                children: const [
                                  Icon(Icons.star_rounded, color: AppColors.orange, size: 14),
                                  SizedBox(width: 2),
                                  Text(
                                    '4.8',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  Text(
                                    ' (56 livraisons)',
                                    style: TextStyle(color: AppColors.slate400, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Bouton Appel
                        IconButton(
                          onPressed: () => _makePhoneCall('+237699000000'),
                          icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.blue50,
                          ),
                        ),
                        // Bouton Message
                        IconButton(
                          onPressed: () => context.push('/chat/${widget.commandeId}'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.blue50,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Timeline verticale des étapes
                  _buildTimelineItem(
                    isCompleted: true,
                    title: 'Commande confirmée',
                    subtitle: 'Aujourd\'hui, 10:24',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    isCompleted: true,
                    title: 'En préparation',
                    subtitle: 'Aujourd\'hui, 10:32',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    isCompleted: false,
                    isCurrent: true,
                    title: 'En cours de livraison',
                    subtitle: 'Arrivée estimée : 15 min',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    isCompleted: false,
                    title: 'Livraison',
                    subtitle: 'Code de confirmation : ${widget.codeConfirmation ?? '482910'}',
                    isLast: true,
                  ),

                  const SizedBox(height: 16),

                  // Message d'aide
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Suivez votre livreur en temps réel sur la carte.',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required bool isCompleted,
    bool isCurrent = false,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    Color dotColor = AppColors.slate300;
    if (isCompleted) dotColor = AppColors.success;
    if (isCurrent) dotColor = AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: isCurrent ? Border.all(color: AppColors.blue100, width: 3) : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? AppColors.success : AppColors.slate200,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isCurrent ? AppColors.primary : AppColors.slate900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
