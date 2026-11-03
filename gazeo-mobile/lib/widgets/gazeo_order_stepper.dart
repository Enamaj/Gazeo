import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Retour fiable : revient à l'écran précédent s'il existe,
/// sinon retourne à l'écran principal (carte) au lieu de ne rien faire.
void gazeoBack(BuildContext context, {String fallback = '/'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Stepper du tunnel de commande : 1. Produits — 2. Livraison — 3. Paiement
class GazeoOrderStepper extends StatelessWidget {
  final int currentStep; // 1, 2 ou 3

  const GazeoOrderStepper({super.key, required this.currentStep});

  static const _labels = ['Produits', 'Livraison', 'Paiement'];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      final step = i + 1;
      children.add(_buildStep(step, _labels[i]));
      if (step < _labels.length) {
        children.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: step < currentStep ? AppColors.primary : AppColors.slate200,
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: children),
    );
  }

  Widget _buildStep(int step, String label) {
    final isDone = step < currentStep;
    final isActive = step == currentStep;
    final highlighted = isDone || isActive;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: highlighted ? AppColors.primary : AppColors.slate100,
            shape: BoxShape.circle,
            border: Border.all(
              color: highlighted ? AppColors.primary : AppColors.slate300,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.slate500,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: highlighted ? AppColors.primary : AppColors.slate500,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

