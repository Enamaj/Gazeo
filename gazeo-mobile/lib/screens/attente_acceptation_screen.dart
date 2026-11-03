import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class AttenteAcceptationScreen extends StatefulWidget {
  final int commandeId;
  final String? paymentUrl;

  const AttenteAcceptationScreen({
    super.key,
    required this.commandeId,
    this.paymentUrl,
  });

  @override
  State<AttenteAcceptationScreen> createState() =>
      _AttenteAcceptationScreenState();
}

class _AttenteAcceptationScreenState extends State<AttenteAcceptationScreen> {
  static const _green = Color(0xFF1D4ED8);
  static const _ink = Color(0xFF102A43);

  final ApiService _apiService = ApiService();
  Timer? _refreshTimer;
  Map<String, dynamic>? _commande;
  bool _isLoading = true;
  bool _isOpeningPayment = false;
  String? _errorMessage;

  String get _statut => _commande?['statut']?.toString() ?? 'EN_ATTENTE';

  @override
  void initState() {
    super.initState();
    _chargerCommande();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _chargerCommande(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _chargerCommande() async {
    try {
      final commande = await _apiService.getCommandeClient(widget.commandeId);
      if (!mounted) return;
      setState(() {
        _commande = commande;
        _isLoading = false;
        _errorMessage = null;
      });
      if (commande['statut'] == 'LIVREE' || commande['statut'] == 'ANNULEE') {
        _refreshTimer?.cancel();
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.response?.statusCode == 401
            ? 'Votre session a expiré. Reconnectez-vous pour consulter cette commande.'
            : 'Impossible d’actualiser le statut. Vérifiez votre connexion.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Impossible de charger la commande : $error';
      });
    }
  }

  Future<void> _ouvrirPaiement() async {
    final url = widget.paymentUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      setState(() => _errorMessage = 'Le lien de paiement est invalide.');
      return;
    }

    setState(() => _isOpeningPayment = true);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _errorMessage = 'Aucune application n’a pu ouvrir la page de paiement. Réessayez.';
        });
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Ouverture du paiement impossible : $error',
      );
    } finally {
      if (mounted) setState(() => _isOpeningPayment = false);
    }
  }

  String get _titreStatut => switch (_statut) {
    'ACCEPTEE' => 'Commande acceptée',
    'EN_LIVRAISON' => 'Votre livreur est en route',
    'LIVREE' => 'Commande livrée',
    'ANNULEE' => 'Commande annulée',
    _ => 'Commande transmise',
  };

  String get _descriptionStatut => switch (_statut) {
    'ACCEPTEE' => 'Le dépôt a accepté votre commande. Gardez le code de confirmation pour la remise de la bouteille.',
    'EN_LIVRAISON' => 'La livraison est en cours. Vous pouvez consulter la position du livreur sur la carte.',
    'LIVREE' => 'La livraison est terminée. Merci d’avoir choisi GAZEO.',
    'ANNULEE' => 'Cette commande a été annulée. Si un paiement a été effectué, contactez l’assistance pour le suivi du remboursement.',
    _ => 'Le dépôt traite votre commande. Le statut sera actualisé automatiquement.',
  };

  Color get _couleurStatut => switch (_statut) {
    'LIVREE' => const Color(0xFF16803C),
    'ANNULEE' => const Color(0xFFB42318),
    'EN_LIVRAISON' => const Color(0xFF175CD3),
    _ => _green,
  };

  @override
  Widget build(BuildContext context) {
    final depotNom =
        _commande?['depot_nom']?.toString() ?? 'Dépôt partenaire GAZEO';
    final address = _commande?['adresse_livraison']?.toString() ?? '';
    final code = _commande?['code_confirmation']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text('Commande #${widget.commandeId}'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => _chargerCommande(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerCommande,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildStatusCard(depotNom),
                  const SizedBox(height: 14),
                  if (widget.paymentUrl != null &&
                      _statut != 'ANNULEE' &&
                      _statut != 'LIVREE')
                    _buildPaymentCard(),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildAddressCard(address),
                  ],
                  if ((_statut == 'ACCEPTEE' || _statut == 'EN_LIVRAISON') &&
                      code != null &&
                      code.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildOtpCard(code),
                  ],
                  if (_statut == 'EN_LIVRAISON') ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/suivi/${widget.commandeId}',
                        extra: code,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Suivre le livreur en direct'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildProgressCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB54708)),
          const SizedBox(width: 10),
          Expanded(child: Text(_errorMessage!)),
          IconButton(
            tooltip: 'Réessayer',
            onPressed: () => _chargerCommande(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String depotNom) {
    return _Panel(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _couleurStatut.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statut == 'LIVREE'
                  ? Icons.check_circle_outline
                  : _statut == 'ANNULEE'
                  ? Icons.cancel_outlined
                  : Icons.hourglass_top_rounded,
              color: _couleurStatut,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _titreStatut,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _descriptionStatut,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              depotNom,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFF175CD3),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paiement sécurisé',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Ouvrez la page de paiement Mobile Money si elle n’est pas déjà ouverte.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Ouvrir le paiement',
            onPressed: _isOpeningPayment ? null : _ouvrirPaiement,
            icon: _isOpeningPayment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(String address) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: _green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adresse de livraison',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(address, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard(String code) {
    return _Panel(
      child: Column(
        children: [
          const Icon(Icons.shield_outlined, color: _green, size: 28),
          const SizedBox(height: 8),
          const Text(
            'Code de confirmation',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            code,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 7,
              fontWeight: FontWeight.w900,
              color: _green,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ne communiquez ce code au livreur qu’après réception de votre bouteille.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final steps = [
      ('Commande créée', true),
      ('Acceptation du dépôt', _statut != 'EN_ATTENTE'),
      ('Livraison', _statut == 'EN_LIVRAISON' || _statut == 'LIVREE'),
      ('Remise confirmée', _statut == 'LIVREE'),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progression',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    steps[index].$2
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: steps[index].$2 ? _green : Colors.black26,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    steps[index].$1,
                    style: TextStyle(
                      color: steps[index].$2 ? _ink : Colors.black54,
                      fontWeight: steps[index].$2
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 22),
          const Row(
            children: [
              Icon(Icons.sync, size: 16, color: Colors.black45),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Actualisation automatique du statut toutes les 12 secondes.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE8EEEB)),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
