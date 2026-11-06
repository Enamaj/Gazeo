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
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        _buildLivreurNavItem(context, index: 0, icon: Icons.home_rounded, label: 'Accueil', route: '/livreur/tableau-de-bord'),
        _buildLivreurNavItem(context, index: 1, icon: Icons.bar_chart_rounded, label: 'Statistiques', route: '/livreur/historique'),
        _buildLivreurNavItem(context, index: 2, icon: Icons.notifications_none_rounded, label: 'Notifications', route: '/livreur/missions', badgeCount: 2),
        _buildLivreurNavItem(context, index: 3, icon: Icons.person_outline_rounded, label: 'Profil', route: '/compte'),
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

  Widget _buildLivreurNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required String route,
    int? badgeCount,
  }) {
    final isSelected = index == currentIndex;

    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0066FF),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0066FF).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: const Color(0xFF64748B), size: 22),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
