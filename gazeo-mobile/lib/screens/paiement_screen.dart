import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';

class PaiementScreen extends StatefulWidget {
  final int? depotId;
  final int montant;
  final int articles;
  final int fraisLivraison;

  const PaiementScreen({
    super.key,
    this.depotId,
    this.montant = 8500,
    this.articles = 1,
    this.fraisLivraison = 1000,
  });

  @override
  State<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends State<PaiementScreen> {
  String _selectedMethod = 'om'; // 'om', 'momo', 'cash'
  bool _isProcessing = false;

  int get _fraisLivraison => widget.fraisLivraison;

  int get _totalAPayer => widget.montant + _fraisLivraison;

  void _validerPaiement() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _isProcessing = false);

    // Redirige vers le suivi de livraison conforme à la maquette
    context.pushReplacement('/suivi/${widget.depotId ?? 1}?otp=482910');
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Paiement sécurisé',
              style: TextStyle(
                color: AppColors.slate900,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GazeoOrderStepper(currentStep: 3),
              const SizedBox(height: 8),
              const Text(
                'Choisissez votre moyen de paiement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate900,
                ),
              ),

              const SizedBox(height: 16),

              // Option 1 : Orange Money
              _buildPaymentOption(
                id: 'om',
                title: 'Orange Money',
                iconBg: const Color(0xFFFF6600),
                iconWidget: Image.asset(
                  'assets/images/orange_money.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Text(
                    'OM',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option 2 : MTN MoMo
              _buildPaymentOption(
                id: 'momo',
                title: 'MTN MoMo',
                iconBg: const Color(0xFFFFCC00),
                iconWidget: Image.asset(
                  'assets/images/mtn_momo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Text(
                    'MTN',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option 3 : Paiement à la livraison
              _buildPaymentOption(
                id: 'cash',
                title: 'Paiement à la livraison',
                iconBg: AppColors.success,
                iconWidget: const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
              ),

              const Spacer(),

              // Récapitulatif des montants
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Montant de la commande',
                          style: TextStyle(color: AppColors.slate600, fontSize: 13),
                        ),
                        Text(
                          '${widget.montant} FCFA',
                          style: const TextStyle(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Frais de livraison',
                          style: TextStyle(color: AppColors.slate600, fontSize: 13),
                        ),
                        Text(
                          _fraisLivraison == 0 ? 'Gratuit (retrait)' : '$_fraisLivraison FCFA',
                          style: const TextStyle(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: AppColors.slate200),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total à payer',
                          style: TextStyle(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$_totalAPayer FCFA',
                          style: const TextStyle(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bouton "Payer maintenant"
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _validerPaiement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Payer maintenant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Note de réassurance sécurité
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.verified_user_outlined, size: 14, color: AppColors.slate400),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Paiement sécurisé par Orange Money / MTN Mobile Money.\nVos informations sont protégées.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.slate400,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required Color iconBg,
    required Widget iconWidget,
  }) {
    final isSelected = _selectedMethod == id;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.slate900,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.slate300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

