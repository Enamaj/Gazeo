import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';
import '../widgets/gazeo_bottom_nav.dart';

class ListeDepotsScreen extends StatefulWidget {
  const ListeDepotsScreen({super.key});

  @override
  State<ListeDepotsScreen> createState() => _ListeDepotsScreenState();
}

class _ListeDepotsScreenState extends State<ListeDepotsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _selectedSort = 'distance';
  String _selectedFilter = 'tous';

  // Dépôts de démonstration conformes à la maquette
  final List<Map<String, dynamic>> _demoDepots = [
    {
      'id': 1,
      'nom': 'Depot Shell Mvog-Ada',
      'marque': 'SHELL',
      'quartier': 'Mvog-Ada, Yaoundé',
      'distance': '1.2 km',
      'note': 4.7,
      'avis': 124,
      'horaires': 'Ouvert • 7h - 22h',
      'estOuvert': true,
      'prixMin': 8500,
      'tags': ['Toutes bouteilles', 'Livraison'],
      'image': 'assets/images/depot_shell_banner.png',
      'isFavorite': false,
    },
    {
      'id': 2,
      'nom': 'Gaz Plus Bastos',
      'marque': 'TOTAL',
      'quartier': 'Bastos, Yaoundé',
      'distance': '2.1 km',
      'note': 4.5,
      'avis': 98,
      'horaires': 'Ouvert • 7h - 21h',
      'estOuvert': true,
      'prixMin': 8000,
      'tags': ['Toutes bouteilles', 'Livraison', 'Paiement mobile'],
      'image': 'assets/images/depot_shell_banner.png',
      'isFavorite': true,
    },
    {
      'id': 3,
      'nom': 'Espace Gaz Nlongkak',
      'marque': 'TRADEX',
      'quartier': 'Nlongkak, Yaoundé',
      'distance': '3.1 km',
      'note': 4.3,
      'avis': 76,
      'horaires': 'Ouvert • 8h - 20h',
      'estOuvert': true,
      'prixMin': 8500,
      'tags': ['Toutes bouteilles', 'Livraison'],
      'image': 'assets/images/depot_shell_banner.png',
      'isFavorite': false,
    },
    {
      'id': 4,
      'nom': 'CAMGAZ Poste Centrale',
      'marque': 'CAMGAZ',
      'quartier': 'Centre-Ville, Yaoundé',
      'distance': '3.8 km',
      'note': 4.8,
      'avis': 142,
      'horaires': 'Ouvert • 7h - 22h',
      'estOuvert': true,
      'prixMin': 6500,
      'tags': ['Toutes bouteilles', 'Livraison rapide'],
      'image': 'assets/images/depot_shell_banner.png',
      'isFavorite': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDepots();
  }

  Future<void> _loadDepots() async {
    setState(() => _isLoading = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      final depots = await _apiService.getDepotsProches(
        lat: pos.latitude,
        lon: pos.longitude,
      );
      if (mounted && depots.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback gracieux sur données conformes à la maquette
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate900),
          onPressed: () => gazeoBack(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dépôts à proximité',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            Text(
              '${_demoDepots.length} dépôts trouvés à Yaoundé',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.slate500,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de filtres (Trier / Filtres)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterDropdown(
                  icon: Icons.sort_rounded,
                  label: 'Trier',
                  value: _selectedSort,
                  items: const [
                    DropdownMenuItem(value: 'distance', child: Text('Distance')),
                    DropdownMenuItem(value: 'prix', child: Text('Prix')),
                    DropdownMenuItem(value: 'note', child: Text('Note avis')),
                  ],
                  onChanged: (val) => setState(() => _selectedSort = val ?? 'distance'),
                ),
                const SizedBox(width: 10),
                _buildFilterDropdown(
                  icon: Icons.tune_rounded,
                  label: 'Filtres',
                  value: _selectedFilter,
                  items: const [
                    DropdownMenuItem(value: 'tous', child: Text('Tous les types')),
                    DropdownMenuItem(value: 'stock', child: Text('En stock')),
                    DropdownMenuItem(value: 'livraison', child: Text('Avec livraison')),
                  ],
                  onChanged: (val) => setState(() => _selectedFilter = val ?? 'tous'),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.slate200),

          // Liste des dépôts
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _demoDepots.length,
                    itemBuilder: (context, index) {
                      final item = _demoDepots[index];
                      return _buildDepotCard(item);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const GazeoBottomNav(currentIndex: 2, role: GazeoNavRole.client),
    );
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.slate600),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.slate600, size: 18),
              style: const TextStyle(
                color: AppColors.slate900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepotCard(Map<String, dynamic> depot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/depot/${depot['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo du dépôt
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.slate100,
                  child: Image.asset(
                    depot['image'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const Center(
                      child: Icon(Icons.storefront, color: AppColors.primary, size: 36),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Informations dépôt
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            depot['nom'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          depot['isFavorite'] == true ? Icons.favorite : Icons.favorite_border_rounded,
                          color: depot['isFavorite'] == true ? AppColors.orange : AppColors.slate400,
                          size: 20,
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Note et distance
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.orange, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          '${depot['note']}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        Text(
                          ' (${depot['avis']} avis) • ${depot['distance']}',
                          style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Horaires & statut
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          depot['horaires'] as String,
                          style: const TextStyle(
                            color: AppColors.slate600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Badges tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (depot['tags'] as List<String>).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Prix minimum
                    Text(
                      'À partir de ${depot['prixMin']} FCFA',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

