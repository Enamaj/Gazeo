import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';

/// Étape 2/3 du tunnel de commande : adresse et mode de livraison.
class CommandeLivraisonScreen extends StatefulWidget {
  final int depotId;
  final String taille;
  final int quantite;
  final int montant;

  const CommandeLivraisonScreen({
    super.key,
    required this.depotId,
    required this.taille,
    required this.quantite,
    required this.montant,
  });

  @override
  State<CommandeLivraisonScreen> createState() => _CommandeLivraisonScreenState();
}

class _CommandeLivraisonScreenState extends State<CommandeLivraisonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quartierController = TextEditingController(text: 'Bastos');
  final _repereController = TextEditingController();
  final _telephoneController = TextEditingController();

  bool _livraisonDomicile = true;
  bool _livrerMaintenant = true;

  static const int _fraisLivraison = 1000;
  int get _frais => _livraisonDomicile ? _fraisLivraison : 0;

  @override
  void dispose() {
    _quartierController.dispose();
    _repereController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  void _continuer() {
    if (_livraisonDomicile && !(_formKey.currentState?.validate() ?? false)) return;
    final uri = Uri(
      path: '/paiement',
      queryParameters: {
        'depotId': '${widget.depotId}',
        'montant': '${widget.montant}',
        'articles': '${widget.quantite}',
        'frais': '$_frais',
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate900),
          onPressed: () => gazeoBack(context),
        ),
        title: const Text(
          'Livraison',
          style: TextStyle(color: AppColors.slate900, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const GazeoOrderStepper(currentStep: 2),
          const Divider(height: 1, color: AppColors.slate100),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _sectionTitle('Mode de réception'),
                  const SizedBox(height: 12),
                  _choiceTile(
                    icon: Icons.two_wheeler_rounded,
                    title: 'Livraison à domicile',
                    subtitle: 'Un livreur moto vous apporte la bouteille',
                    trailing: '$_fraisLivraison FCFA',
                    selected: _livraisonDomicile,
                    onTap: () => setState(() => _livraisonDomicile = true),
                  ),
                  const SizedBox(height: 10),
                  _choiceTile(
                    icon: Icons.storefront_outlined,
                    title: 'Retrait au dépôt',
                    subtitle: 'Vous récupérez la bouteille vous-même',
                    trailing: 'Gratuit',
                    selected: !_livraisonDomicile,
                    onTap: () => setState(() => _livraisonDomicile = false),
                  ),
                  if (_livraisonDomicile) ...[
                    const SizedBox(height: 24),
                    _sectionTitle('Adresse de livraison'),
                    const SizedBox(height: 12),
                    _field(
                      controller: _quartierController,
                      label: 'Quartier',
                      icon: Icons.location_on_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez votre quartier' : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _repereController,
                      label: 'Point de repère (ex : face pharmacie)',
                      icon: Icons.signpost_outlined,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _telephoneController,
                      label: 'Téléphone à joindre',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        return digits.length < 9 ? 'Numéro invalide (9 chiffres)' : null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Quand ?'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _pill('Maintenant', _livrerMaintenant, () => setState(() => _livrerMaintenant = true))),
                        const SizedBox(width: 10),
                        Expanded(child: _pill('Plus tard', !_livrerMaintenant, () => setState(() => _livrerMaintenant = false))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
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
                      Text('${widget.quantite} × ${widget.taille} + livraison',
                          style: const TextStyle(color: AppColors.slate600, fontSize: 14)),
                      Text('${widget.montant + _frais} FCFA',
                          style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _continuer,
                      child: const Text('Continuer vers le paiement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
      );

  Widget _choiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.blue50 : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.slate200, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate900)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                  ],
                ),
              ),
              Text(trailing, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.slate200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.slate200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? AppColors.primary : AppColors.slate200),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(color: selected ? Colors.white : AppColors.slate700, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

