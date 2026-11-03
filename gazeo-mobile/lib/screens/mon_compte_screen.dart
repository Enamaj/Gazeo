import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_bottom_nav.dart';

class MonCompteScreen extends StatefulWidget {
  const MonCompteScreen({super.key});

  @override
  State<MonCompteScreen> createState() => _MonCompteScreenState();
}

class _MonCompteScreenState extends State<MonCompteScreen> {
  final AuthService _authService = AuthService();
  final String _userName = 'Junior Enama';
  String _userPhone = '+237 6 12 34 56 78';
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final phone = await _authService.getUserPhone();
    final role = await _authService.getUserRole();
    if (mounted) {
      setState(() {
        if (phone != null && phone.isNotEmpty) {
          _userPhone = phone;
        }
        _userRole = role;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. En-tête courbé Bleu Nuit avec Avatar et Informations utilisateur
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 190,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.darkNavy,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar avec anneau blanc
                          Stack(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  color: AppColors.slate200,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/user_avatar.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Icon(
                                      Icons.person,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryLight,
                                  ),
                                  child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 14),

                          // Nom et statut Premium
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _userPhone,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFBBF24), width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFFBBF24)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Client Premium',
                                        style: TextStyle(
                                          color: Color(0xFFFBBF24),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bouton choix de compte / switch
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                            tooltip: 'Changer de profil',
                            onPressed: () => context.push('/choix-compte'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Carte Solde Fidélité flottante
                Positioned(
                  top: 145,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0E000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mon solde fidélité',
                              style: TextStyle(color: AppColors.slate500, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Icon(Icons.stars_rounded, color: AppColors.orange, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  '125 points',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text(
                            'Voir les avantages',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // 3. Liste des menus
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200, width: 0.8),
                ),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: Icons.inventory_2_outlined,
                      title: 'Mes commandes',
                      onTap: () => context.push('/commande/selection/1'),
                    ),
                    const Divider(height: 1, indent: 54, color: AppColors.slate100),
                    _buildMenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'Mes adresses',
                      onTap: () => context.push('/compte/adresses'),
                    ),
                    const Divider(height: 1, indent: 54, color: AppColors.slate100),
                    _buildMenuTile(
                      icon: Icons.credit_card_outlined,
                      title: 'Modes de paiement',
                      onTap: () => context.push('/paiement'),
                    ),
                    const Divider(height: 1, indent: 54, color: AppColors.slate100),
                    _buildMenuTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      onTap: () => context.push('/compte/notifications'),
                    ),
                    const Divider(height: 1, indent: 54, color: AppColors.slate100),
                    _buildMenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Aide & Support',
                      onTap: () => context.push('/compte/aide'),
                    ),
                    const Divider(height: 1, indent: 54, color: AppColors.slate100),
                    _buildMenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Paramètres',
                      onTap: () => context.push('/compte/parametres'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Déconnexion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextButton.icon(
                onPressed: () => context.push('/connexion'),
                icon: const Icon(Icons.logout, color: AppColors.error, size: 18),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: GazeoBottomNav(
        currentIndex: 3,
        role: _userRole?.toUpperCase() == 'LIVREUR'
            ? GazeoNavRole.livreur
            : _userRole?.toUpperCase() == 'GERANT'
                ? GazeoNavRole.gerant
                : GazeoNavRole.client,
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.slate900,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate400, size: 20),
      ),
    );
  }
}

