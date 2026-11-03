import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';

/// Étape 1/3 du tunnel de commande : choix de la bouteille et de la quantité.
class CommandeSelectionScreen extends StatefulWidget {
  final int depotId;
  final String? tailleInitiale;

  const CommandeSelectionScreen({
    super.key,
    required this.depotId,
    this.tailleInitiale,
  });

  @override
  State<CommandeSelectionScreen> createState() => _CommandeSelectionScreenState();
}

class _BottleOption {
  final String taille;
  final String description;
  int prix;
  _BottleOption(this.taille, this.description, this.prix);
}

class _CommandeSelectionScreenState extends State<CommandeSelectionScreen> {
  final ApiService _apiService = ApiService();

  final List<_BottleOption> _options = [
    _BottleOption('6 kg', 'Idéal pour 1 à 2 personnes', 8500),
    _BottleOption('12.5 kg', 'Parfait pour une famille', 13000),
    _BottleOption('22 kg', 'Pour les grands ménages', 22000),
  ];

  late String _selectedTaille;
  int _quantite = 1;

  @override
  void initState() {
    super.initState();
    final initiale = widget.tailleInitiale;
    _selectedTaille = _options.any((o) => o.taille == initiale) ? initiale! : '12.5 kg';
    _chargerPrix();
  }

  /// Récupère les vrais prix du dépôt si l'API est disponible.
  Future<void> _chargerPrix() async {
    try {
      final depot = await _apiService.getDepotDetail(widget.depotId);
      final p6 = num.tryParse('${depot['prix_6kg']}');
      final p12 = num.tryParse('${depot['prix_12kg']}');
      if (!mounted) return;
      setState(() {
        if (p6 != null && p6 > 0) _options[0].prix = p6.toInt();
        if (p12 != null && p12 > 0) _options[1].prix = p12.toInt();
      });
    } catch (_) {
      // On conserve les prix par défaut.
    }
  }

  _BottleOption get _selected => _options.firstWhere((o) => o.taille == _selectedTaille);
  int get _total => _selected.prix * _quantite;

  void _continuer() {
    final uri = Uri(
      path: '/commande/livraison',
      queryParameters: {
        'depotId': '${widget.depotId}',
        'taille': _selectedTaille,
        'quantite': '$_quantite',
        'montant': '$_total',
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate900),
            onPressed: () => gazeoBack(context),
          ),
          title: const Text(
            'Commander',
            style: TextStyle(color: AppColors.slate900, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const GazeoOrderStepper(currentStep: 1),
            const Divider(height: 1, color: AppColors.slate100),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Sélectionnez votre bouteille',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Appuyez sur une bouteille pour la choisir.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 16),
                  for (final option in _options) ...[
                    _buildBottleItem(option),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ($_quantite × $_selectedTaille)',
                  style: const TextStyle(color: AppColors.slate600, fontSize: 14),
                ),
                Text(
                  '$_total FCFA',
                  style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _continuer,
                child: const Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottleItem(_BottleOption option) {
    final isSelected = option.taille == _selectedTaille;

    return Material(
      color: isSelected ? AppColors.blue50 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          if (!isSelected) {
            _selectedTaille = option.taille;
            _quantite = 1;
          }
        }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.slate200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.primary : AppColors.slate300,
                size: 22,
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 56,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.blue50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'assets/images/gas_cylinder_blue.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) =>
                      const Icon(Icons.propane_tank, color: AppColors.primary, size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.taille,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                    Text(option.description, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                    const SizedBox(height: 4),
                    Text('${option.prix} FCFA',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
              if (isSelected) _buildQuantityCounter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityCounter() {
    return Row(
      children: [
        _roundButton(
          icon: Icons.remove,
          filled: false,
          onTap: _quantite > 1 ? () => setState(() => _quantite--) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$_quantite',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.slate900)),
        ),
        _roundButton(
          icon: Icons.add,
          filled: true,
          onTap: _quantite < 10 ? () => setState(() => _quantite++) : null,
        ),
      ],
    );
  }

  Widget _roundButton({required IconData icon, required bool filled, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? (enabled ? AppColors.primary : AppColors.slate200) : Colors.white,
          border: filled ? null : Border.all(color: AppColors.slate300),
        ),
        child: Icon(icon, size: 16, color: filled ? Colors.white : (enabled ? AppColors.slate700 : AppColors.slate300)),
      ),
    );
  }
}
