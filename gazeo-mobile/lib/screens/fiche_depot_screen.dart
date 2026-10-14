import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class FicheDepotScreen extends StatefulWidget {
  final int depotId;

  const FicheDepotScreen({super.key, required this.depotId});

  @override
  State<FicheDepotScreen> createState() => _FicheDepotScreenState();
}

class _FicheDepotScreenState extends State<FicheDepotScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _depot;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadDepot();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final logged = await _authService.isLoggedIn();
    if (mounted) setState(() => _isLoggedIn = logged);
  }

  Future<void> _loadDepot() async {
    try {
      final data = await _apiService.getDepotDetail(widget.depotId);
      if (mounted) {
        setState(() {
          _depot = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement détails : $e')),
        );
      }
    }
  }

  Future<void> _openGoogleMapsItinerary() async {
    if (_depot == null) return;
    final lat = _depot!['latitude'];
    final lon = _depot!['longitude'];
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application de carte.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_depot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dépôt')),
        body: const Center(child: Text('Dépôt introuvable')),
      );
    }

    final nom = _depot!['nom'] ?? 'Dépôt de gaz';
    final marque = _depot!['marque'] ?? 'TRADEX';
    final quartier = _depot!['quartier'] ?? 'Yaoundé';
    final adresse = _depot!['adresse'] ?? '';
    final telephone = _depot!['telephone'] ?? '';
    final stock6kg = _depot!['stock_6kg'] ?? 0;
    final stock12kg = _depot!['stock_12kg'] ?? 0;
    final prix6kg = _depot!['prix_6kg'] ?? 3000;
    final prix12kg = _depot!['prix_12kg'] ?? 6500;
    final noteMoyenne = _depot!['note_moyenne'] ?? 5.0;
    final totalAvis = _depot!['total_avis'] ?? 0;
    final derniersAvis = _depot!['derniers_avis'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(nom),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête Dépôt
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.verified, size: 16, color: Colors.blue),
                          label: Text(marque, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '$noteMoyenne / 5',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(' ($totalAvis avis)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text('$quartier — $adresse', style: TextStyle(color: Colors.grey[700]))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(telephone, style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('Disponibilité & Tarifs officiels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Cartes Bouteilles 6kg et 12.5kg
            Row(
              children: [
                Expanded(
                  child: _buildBouteilleCard(
                    taille: '6 kg',
                    stock: stock6kg,
                    prix: '$prix6kg FCFA',
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBouteilleCard(
                    taille: '12.5 kg',
                    stock: stock12kg,
                    prix: '$prix12kg FCFA',
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            // Actions : Bouton Itinéraire & Commander
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openGoogleMapsItinerary,
                    icon: const Icon(Icons.directions),
                    label: const Text('Itinéraire'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!_isLoggedIn) {
                        _showLoginPrompt();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passage de commande (activé en Phase 4)')),
                        );
                      }
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Commander'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            // Section Avis clients
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Avis des clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$totalAvis avis enregistrés', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 12),

            if (derniersAvis.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Aucun avis pour le moment. Soyez le premier à commander !', style: TextStyle(color: Colors.grey)),
                ),
              ),

            ...derniersAvis.map((avis) => _buildAvisTile(avis)),
          ],
        ),
      ),
    );
  }

  Widget _buildBouteilleCard({
    required String taille,
    required int stock,
    required String prix,
    required Color color,
  }) {
    final enRupture = stock <= 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.propane_tank, size: 36, color: color),
            const SizedBox(height: 6),
            Text('Bouteille $taille', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(prix, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: enRupture ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                enRupture ? 'Rupture' : '$stock en stock',
                style: TextStyle(
                  color: enRupture ? Colors.red : Colors.green[800],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvisTile(Map<String, dynamic> avis) {
    final note = avis['note'] ?? 5;
    final commentaire = avis['commentaire'] ?? '';
    final clientTel = avis['client_telephone'] ?? 'Client GAZEO';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.person, color: Colors.grey),
        ),
        title: Row(
          children: [
            Text(clientTel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            ...List.generate(5, (index) => Icon(
              Icons.star,
              size: 14,
              color: index < note ? Colors.amber : Colors.grey[300],
            )),
          ],
        ),
        subtitle: commentaire.isNotEmpty ? Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(commentaire, style: const TextStyle(fontSize: 13)),
        ) : null,
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text(
          'Pour commander une recharge de gaz, veuillez vous connecter ou créer votre compte avec votre numéro de téléphone camerounais.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Connexion
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

