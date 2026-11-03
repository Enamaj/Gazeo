import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';

class FicheDepotScreen extends StatefulWidget {
  final int depotId;

  const FicheDepotScreen({super.key, required this.depotId});

  @override
  State<FicheDepotScreen> createState() => _FicheDepotScreenState();
}

class _FicheDepotScreenState extends State<FicheDepotScreen> {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _depot;
  bool _isLoading = true;
  bool _isFavorite = false;
  String _selectedSize = '12.5 kg';

  @override
  void initState() {
    super.initState();
    _loadDepot();
  }

  Future<void> _loadDepot() async {
    try {
      final data = await _apiService.getDepotDetail(widget.depotId);
      if (mounted) {
        setState(() {
          _depot = data;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback avec données de démonstration conformes à la maquette
    if (mounted) {
      setState(() {
        _depot = {
          'id': widget.depotId,
          'nom': 'Depot Shell Mvog-Ada',
          'marque': 'SHELL',
          'quartier': 'Mvog-Ada, Yaoundé',
          'distance': '1.2 km',
          'note': 4.7,
          'avis': 124,
          'horaires': 'Ouvert • 7h - 22h',
          'stock_6kg': 14,
          'stock_12kg': 28,
          'stock_22kg': 8,
          'prix_6kg': 8500,
          'prix_12kg': 13000,
          'prix_22kg': 22000,
          'tags': ['Toutes bouteilles', 'Livraison', 'Paiement mobile'],
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final nom = _depot?['nom'] ?? 'Depot Shell Mvog-Ada';
    final quartier = _depot?['quartier'] ?? 'Mvog-Ada, Yaoundé';
    final distance = _depot?['distance'] ?? '1.2 km';
    final note = (_depot?['note'] as num?)?.toDouble() ?? 4.7;
    final avis = _depot?['avis'] ?? 124;
    final horaires = _depot?['horaires'] ?? 'Ouvert • 7h - 22h';
    final tags = (_depot?['tags'] as List?)?.cast<String>() ?? ['Toutes bouteilles', 'Livraison', 'Paiement mobile'];

    final prix6kg = (_depot?['prix_6kg'] as num?)?.toInt() ?? 8500;
    final prix12kg = (_depot?['prix_12kg'] as num?)?.toInt() ?? 13000;
    final prix22kg = (_depot?['prix_22kg'] as num?)?.toInt() ?? 22000;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Bannière Image Station Shell
                Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: AppColors.slate100,
                      child: Image.asset(
                        'assets/images/depot_shell_banner.png',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: AppColors.blue50,
                          child: const Center(
                            child: Icon(Icons.storefront, size: 70, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),

                    // Boutons de navigation supérieurs
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.slate900),
                                onPressed: () => gazeoBack(context),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.slate900),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Bloc d'informations Dépôt
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nom,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Note & avis
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '$note',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          Text(
                            ' ($avis avis)',
                            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Adresse et distance
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.slate500, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$distance • $quartier',
                            style: const TextStyle(color: AppColors.slate600, fontSize: 13),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Statut ouvert
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            horaires,
                            style: const TextStyle(
                              color: AppColors.slate700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Tags puces
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tags.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.blue50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // 3. Section Types de gaz disponibles
                      const Text(
                        'Types de gaz disponibles',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _buildBouteilleChoiceCard(
                              taille: '6 kg',
                              prix: '$prix6kg FCFA',
                              isSelected: _selectedSize == '6 kg',
                              onTap: () => setState(() => _selectedSize = '6 kg'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildBouteilleChoiceCard(
                              taille: '12.5 kg',
                              prix: '$prix12kg FCFA',
                              isSelected: _selectedSize == '12.5 kg',
                              onTap: () => setState(() => _selectedSize = '12.5 kg'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildBouteilleChoiceCard(
                              taille: '22 kg',
                              prix: '$prix22kg FCFA',
                              isSelected: _selectedSize == '22 kg',
                              onTap: () => setState(() => _selectedSize = '22 kg'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Boutons "Commander maintenant" et "Ajouter aux favoris" ancrés tout en bas
          bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate200, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    context.push(
                      Uri(
                        path: '/commande/selection/${widget.depotId}',
                        queryParameters: {'taille': _selectedSize},
                      ).toString(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text(
                    'Commander maintenant',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _isFavorite = !_isFavorite);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isFavorite ? 'Ajouté à vos favoris' : 'Retiré de vos favoris',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(
                    _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isFavorite ? 'Dans vos favoris' : 'Ajouter aux favoris',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBouteilleChoiceCard({
    required String taille,
    required String prix,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Bouteille de gaz bleue
            SizedBox(
              height: 48,
              child: Image.asset(
                'assets/images/gas_cylinder_blue.png',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const Icon(
                  Icons.propane_tank,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              taille,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              prix,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
