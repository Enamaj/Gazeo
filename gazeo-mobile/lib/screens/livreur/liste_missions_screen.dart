import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gazeo_bottom_nav.dart';

class ListeMissionsScreen extends StatefulWidget {
  const ListeMissionsScreen({super.key});

  @override
  State<ListeMissionsScreen> createState() => _ListeMissionsScreenState();
}

class _ListeMissionsScreenState extends State<ListeMissionsScreen> {
  int _selectedTab = 0; // 0: À venir, 1: En cours, 2: Terminées

  final List<Map<String, dynamic>> _demoMissionsAVenir = [
    {
      'id': 1048,
      'code': '#GAZ-2026-1048',
      'client': 'M. Nguimatsia',
      'bouteille': '12.5 kg - 13 000 FCFA',
      'quartier': 'Mvog-Ada',
      'distance': '2.4 km',
      'statut': 'À venir',
    },
    {
      'id': 1047,
      'code': '#GAZ-2026-1047',
      'client': 'Mme Tchouake',
      'bouteille': '22 kg - 22 000 FCFA',
      'quartier': 'Bastos',
      'distance': '3.1 km',
      'statut': 'À venir',
    },
    {
      'id': 1046,
      'code': '#GAZ-2026-1046',
      'client': 'M. Djoumessi',
      'bouteille': '6 kg - 8 500 FCFA',
      'quartier': 'Nlongkak',
      'distance': '4.8 km',
      'statut': 'À venir',
    },
  ];

  final List<Map<String, dynamic>> _demoMissionsEnCours = [
    {
      'id': 1045,
      'code': '#GAZ-2026-1045',
      'client': 'M. Roger Milla',
      'bouteille': '12.5 kg - 13 000 FCFA',
      'quartier': 'Omnisports',
      'distance': '1.1 km',
      'statut': 'En cours',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedTab == 0
        ? _demoMissionsAVenir
        : _selectedTab == 1
            ? _demoMissionsEnCours
            : [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitOrSwitchModal(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, size: 22, color: AppColors.primary),
            tooltip: 'Changer de profil',
            onPressed: () => _showExitOrSwitchModal(context),
          ),
          title: const Text(
            'Mes missions',
            style: TextStyle(
              color: AppColors.slate900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: AppColors.success, size: 8),
                  SizedBox(width: 5),
                  Text(
                    'En service',
                    style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
        children: [
          // Contrôle segmenté (À venir (3) | En cours (1) | Terminées)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    label: 'À venir (${_demoMissionsAVenir.length})',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    label: 'En cours (${_demoMissionsEnCours.length})',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    index: 2,
                    label: 'Terminées',
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.slate200),

          // Liste des missions
          Expanded(
            child: currentList.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune mission terminée pour le moment.',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 90.0),
                    itemCount: currentList.length,
                    itemBuilder: (context, index) {
                      final m = currentList[index];
                      return _buildMissionCard(m);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const GazeoBottomNav(currentIndex: 0, role: GazeoNavRole.livreur),
    ),
  );
}

  void _showExitOrSwitchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.two_wheeler, color: AppColors.primary, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Espace Livreur GAZEO',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Vous êtes actuellement connecté en tant que Livreur. Que souhaitez-vous faire ?',
                style: TextStyle(color: AppColors.slate600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz, color: AppColors.primary),
                ),
                title: const Text('Changer de rôle / compte', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Passer en mode client ou gérant'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/choix-compte');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.error),
                ),
                title: const Text('Se déconnecter', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                subtitle: const Text('Quitter la session livreur'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/connexion');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({required int index, required String label}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.slate600,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionCard(Map<String, dynamic> mission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Code commande & Badge statut vert
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mission['code'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.slate900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  mission['statut'] as String,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Client et Bouteille
          Text(
            'Client : ${mission['client']}',
            style: const TextStyle(color: AppColors.slate700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            mission['bouteille'] as String,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          // Localisation et distance
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.slate400, size: 16),
              const SizedBox(width: 4),
              Text(
                '${mission['quartier']} (${mission['distance']})',
                style: const TextStyle(color: AppColors.slate500, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bouton bleu "Voir l'itinéraire"
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/suivi/${mission['id']}');
              },
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text(
                "Voir l'itinéraire",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
