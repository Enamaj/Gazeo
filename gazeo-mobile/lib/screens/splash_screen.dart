import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Écran de chargement au démarrage : logo GAZEO + barre de progression,
/// puis redirection automatique vers l'écran d'accueil.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          context.go('/accueil');
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _message(double v) {
    if (v < 0.35) return 'Initialisation...';
    if (v < 0.70) return 'Recherche des dépôts à proximité...';
    return 'Presque prêt...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset('assets/images/gazeo_logo.png', width: 120, height: 120),
              const SizedBox(height: 20),
              const Text(
                'GAZEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Trouvez votre gaz. Partout. Maintenant.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final v = Curves.easeInOut.transform(_controller.value);
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _message(v),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            '${(v * 100).round()} %',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
