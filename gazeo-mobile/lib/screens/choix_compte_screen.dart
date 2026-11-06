import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class ChoixCompteScreen extends StatelessWidget {
  const ChoixCompteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FC),
      body: Stack(
        children: [
          // 1. Fond décoratif avec bouteille bleue et monument de Yaoundé en haut à droite
          Positioned(
            top: 40,
            right: 0,
            child: Opacity(
              opacity: 0.95,
              child: Image.asset(
                'assets/images/choix_header_bottle.png',
                width: size.width * 0.46,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 2. Décoration vague bleue et silhouette ville en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/city_skyline_footer.png',
                width: size.width,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),

          // 3. Contenu principal défilable
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête : Logo GAZEO + Sélecteur de langue FR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F2C59).withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/gazeo_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'GAZEO',
                                style: TextStyle(
                                  color: Color(0xFF0F2C59),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              Text(
                                'Trouvez votre gaz. Partout. Maintenant.',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Sélecteur de langue
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F2C59).withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.language_rounded, size: 16, color: Color(0xFF0F2C59)),
                            SizedBox(width: 4),
                            Text(
                              'FR',
                              style: TextStyle(
                                color: Color(0xFF0F2C59),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Titre principal
                  SizedBox(
                    width: size.width * 0.65,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: Color(0xFF0F2C59),
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                        children: [
                          TextSpan(text: 'Comment\nsouhaitez-vous\nvous '),
                          TextSpan(
                            text: 'connecter ?',
                            style: TextStyle(color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Sous-titre avec barre bleue
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3.5,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Accédez rapidement à votre espace\net profitez de nos services.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Carte 1 : En tant que client
                  _buildRoleCard(
                    context,
                    imagePath: 'assets/images/client_avatar.png',
                    roleBadge: 'Client',
                    roleIcon: Icons.person_rounded,
                    title: 'En tant que client',
                    subtitle: 'Trouvez et commandez votre gaz facilement',
                    onTap: () async {
                      await AuthService().saveRole('CLIENT');
                      if (context.mounted) context.go('/');
                    },
                  ),

                  const SizedBox(height: 14),

                  // Carte 2 : En tant que gérant de dépôt
                  _buildRoleCard(
                    context,
                    imagePath: 'assets/images/gerant_avatar.png',
                    roleBadge: 'Gérant',
                    roleIcon: Icons.storefront_rounded,
                    title: 'En tant que gérant de dépôt',
                    subtitle: 'Gérez votre stock et vos commandes',
                    onTap: () async {
                      await AuthService().saveRole('GERANT');
                      if (context.mounted) context.go('/gerant/tableau-de-bord');
                    },
                  ),

                  const SizedBox(height: 14),

                  // Carte 3 : En tant que livreur
                  _buildRoleCard(
                    context,
                    imagePath: 'assets/images/livreur_scooter_avatar.png',
                    roleBadge: 'Livreur',
                    roleIcon: Icons.two_wheeler_rounded,
                    title: 'En tant que livreur',
                    subtitle: 'Recevez vos missions et livrez vos commandes',
                    onTap: () async {
                      await AuthService().saveRole('LIVREUR');
                      if (context.mounted) context.go('/livreur/tableau-de-bord');
                    },
                  ),

                  const SizedBox(height: 22),

                  // Pastille "Vous n'avez pas de compte ? Inscrivez-vous >"
                  Center(
                    child: InkWell(
                      onTap: () => context.go('/connexion'),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F2C59).withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0066FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Vous n'avez pas de compte ? ",
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              'Inscrivez-vous >',
                              style: TextStyle(
                                color: Color(0xFF0066FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Slogan cursif centré
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Ensemble pour une ville mieux servie',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 100,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String imagePath,
    required String roleBadge,
    required IconData roleIcon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2C59).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Portrait photo avec coins arrondis
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 82,
                height: 82,
                color: const Color(0xFFEFF6FF),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Textes et badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge bleu du rôle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          roleBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F2C59),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),

            // Bouton flèche bleue
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF0066FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
