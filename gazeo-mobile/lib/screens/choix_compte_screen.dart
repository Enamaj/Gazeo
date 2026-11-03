import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ChoixCompteScreen extends StatelessWidget {
  const ChoixCompteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Logo officiel GAZEO
              Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/images/gazeo_logo.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'GAZEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Titre de sélection
              const Text(
                'Comment souhaitez-vous\nvous connecter ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 36),

              // Carte 1 : En tant que client
              _buildRoleCard(
                context,
                icon: Icons.person_outline_rounded,
                title: 'En tant que client',
                subtitle: 'Trouvez et commandez votre gaz',
                onTap: () async {
                  await AuthService().saveRole('CLIENT');
                  if (context.mounted) context.go('/');
                },
              ),

              const SizedBox(height: 16),

              // Carte 2 : En tant que gérant de dépôt
              _buildRoleCard(
                context,
                icon: Icons.storefront_outlined,
                title: 'En tant que gérant de dépôt',
                subtitle: 'Gérez votre stock et vos commandes',
                onTap: () async {
                  await AuthService().saveRole('GERANT');
                  if (context.mounted) context.go('/gerant/tableau-de-bord');
                },
              ),

              const SizedBox(height: 16),

              // Carte 3 : En tant que livreur
              _buildRoleCard(
                context,
                icon: Icons.two_wheeler_outlined,
                title: 'En tant que livreur',
                subtitle: 'Recevez vos missions et livrez',
                onTap: () async {
                  await AuthService().saveRole('LIVREUR');
                  if (context.mounted) context.go('/livreur/missions');
                },
              ),

              const Spacer(),

              // Lien inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Vous n'avez pas de compte ? ",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/connexion'),
                    child: const Text(
                      'Inscrivez-vous',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkCardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

