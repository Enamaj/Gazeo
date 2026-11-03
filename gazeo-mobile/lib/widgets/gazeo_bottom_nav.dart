import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

enum GazeoNavRole { client, gerant, livreur }

class GazeoBottomNav extends StatelessWidget {
  final int currentIndex;
  final GazeoNavRole role;

  const GazeoBottomNav({
    super.key,
    required this.currentIndex,
    this.role = GazeoNavRole.client,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _buildItems(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    if (role == GazeoNavRole.gerant) {
      return [
        _buildNavItem(context, index: 0, icon: Icons.home_rounded, label: 'Accueil', route: '/'),
        _buildNavItem(context, index: 1, icon: Icons.assignment_outlined, label: 'Commandes', route: '/gerant/commandes'),
        _buildNavItem(context, index: 2, icon: Icons.inventory_2_outlined, label: 'Stock', route: '/gerant/tableau-de-bord'),
        _buildNavItem(context, index: 3, icon: Icons.person_outline_rounded, label: 'Profil', route: '/compte'),
      ];
    } else if (role == GazeoNavRole.livreur) {
      return [
        _buildNavItem(context, index: 0, icon: Icons.assignment_outlined, label: 'Missions', route: '/livreur/missions'),
        _buildNavItem(context, index: 1, icon: Icons.two_wheeler_outlined, label: 'En cours', route: '/livreur/tableau-de-bord'),
        _buildNavItem(context, index: 2, icon: Icons.history_rounded, label: 'Historique', route: '/livreur/historique'),
        _buildNavItem(context, index: 3, icon: Icons.person_outline_rounded, label: 'Profil', route: '/compte'),
      ];
    }

    // Role client (default)
    return [
      _buildNavItem(context, index: 0, icon: Icons.home_rounded, label: 'Accueil', route: '/'),
      _buildNavItem(context, index: 1, icon: Icons.receipt_long_outlined, label: 'Commandes', route: '/commande/selection/1'),
      _buildNavItem(context, index: 2, icon: Icons.favorite_border_rounded, label: 'Favoris', route: '/depots'),
      _buildNavItem(context, index: 3, icon: Icons.person_outline_rounded, label: 'Profil', route: '/compte'),
    ];
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isSelected = index == currentIndex;
    final color = isSelected ? AppColors.primary : AppColors.slate400;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          context.go(route);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

