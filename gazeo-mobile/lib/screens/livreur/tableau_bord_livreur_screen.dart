import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/mission_livreur.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/gazeo_bottom_nav.dart';

class TableauBordLivreurScreen extends StatefulWidget {
  const TableauBordLivreurScreen({super.key});

  @override
  State<TableauBordLivreurScreen> createState() =>
      _TableauBordLivreurScreenState();
}

class _TableauBordLivreurScreenState extends State<TableauBordLivreurScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  bool _isLoading = false;
  bool _estDisponible = true;
  int _missionsJour = 0;
  double _revenusJour = 0.0;
  double _noteMoyenne = 5.0;
  MissionLivreur? _missionActive;
  String _userPhone = '+237 699 00 00 00';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = await _authService.getUserPhone();
      if (phone != null && phone.isNotEmpty) {
        _userPhone = phone;
      }

      final data = await _apiService.getLivreurTableauDeBord();

      if (mounted) {
        setState(() {
          _estDisponible = data['est_disponible'] ?? true;
          _missionsJour = data['missions_jour'] ?? 0;
          _revenusJour = (data['revenus_jour'] as num?)?.toDouble() ?? 0.0;
          _noteMoyenne = (data['note_moyenne'] as num?)?.toDouble() ?? 5.0;

          if (data['mission_active'] != null) {
            _missionActive = MissionLivreur.fromJson(data['mission_active']);
          } else {
            _missionActive = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Impossible de charger le tableau de bord.\nVérifiez votre connexion.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDisponibilite(bool value) async {
    setState(() => _estDisponible = value);
    try {
      final newState = await _apiService.toggleDisponibilite(
        estDisponible: value,
      );
      if (mounted) {
        setState(() => _estDisponible = newState);
      }
    } catch (_) {
      // Garder l'état local fluide
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitOrSwitchModal(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F6FC),
        body: Stack(
          children: [
            // Fond courbe en haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF003399), Color(0xFF0055DD), Color(0xFF0066FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // 1. En-tête / App Bar personnalisé
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        // Bouton retour
                        InkWell(
                          onTap: () => _showExitOrSwitchModal(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Logo GAZEO
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/gazeo_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'GAZEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'Toujours plus proche de vous',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // Ligne de séparation
                        Container(
                          width: 1.2,
                          height: 22,
                          color: Colors.white24,
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Text(
                            'Espace Livreur',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        // Bouton carte
                        InkWell(
                          onTap: () => context.go('/livreur/missions'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isLoading)
                    const LinearProgressIndicator(
                      minHeight: 2.5,
                      color: Color(0xFF38BDF8),
                      backgroundColor: Colors.transparent,
                    ),

                  // 2. Contenu principal défilable
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _chargerDonnees,
                      color: const Color(0xFF0066FF),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bannière alerte (si connexion coupée ou erreur)
                            if (_errorMessage != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFECEC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEA580C),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.priority_high_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Impossible de charger le tableau de bord.',
                                            style: TextStyle(
                                              color: Color(0xFFB91C1C),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Vérifiez votre connexion.',
                                            style: TextStyle(
                                              color: Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.wifi_off_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Carte Profil Livreur & Switch Disponibilité
                            Container(
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
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Photo du livreur avec pouce levé
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 90,
                                      height: 110,
                                      color: const Color(0xFFEFF6FF),
                                      child: Image.asset(
                                        'assets/images/livreur_thumbsup_avatar.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  // Informations et toggle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Badges Partenaire & En Ligne
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0066FF),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.two_wheeler_rounded, size: 11, color: Colors.white),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Livreur Partenaire',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _estDisponible
                                                    ? const Color(0xFFDCFCE7)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: _estDisponible
                                                          ? const Color(0xFF16A34A)
                                                          : const Color(0xFF94A3B8),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    _estDisponible ? 'EN LIGNE' : 'HORS LIGNE',
                                                    style: TextStyle(
                                                      color: _estDisponible
                                                          ? const Color(0xFF15803D)
                                                          : const Color(0xFF64748B),
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        // Téléphone du livreur
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_android_rounded,
                                              size: 15,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _userPhone.length > 7
                                                  ? '${_userPhone.substring(0, 4)} ...'
                                                  : _userPhone,
                                              style: const TextStyle(
                                                color: Color(0xFF0F2C59),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        // Switch disponibilité
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: const [
                                                  Text(
                                                    'Disponibilité pour livrer',
                                                    style: TextStyle(
                                                      color: Color(0xFF0F2C59),
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Vous recevez les alertes de nouvelles missions',
                                                    style: TextStyle(
                                                      color: Color(0xFF64748B),
                                                      fontSize: 9.5,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            CupertinoSwitch(
                                              value: _estDisponible,
                                              activeTrackColor: const Color(0xFF0066FF),
                                              onChanged: _toggleDisponibilite,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Bannière de mission active (si course en cours)
                            if (_missionActive != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF0066FF)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0066FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Course en cours',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Color(0xFF0066FF),
                                            ),
                                          ),
                                          Text(
                                            _missionActive!.adresseLivraison,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Color(0xFF0F2C59),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => context.go('/livreur/mission-active'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0066FF),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      child: const Text('Suivre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Section : Aujourd'hui à Yaoundé
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F2C59),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.bar_chart_rounded, color: Color(0xFF38BDF8), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    "Aujourd'hui à Yaoundé",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Les 3 cartes de statistiques
                            Row(
                              children: [
                                // Missions
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.assignment_outlined,
                                    iconColor: const Color(0xFF0066FF),
                                    iconBg: const Color(0xFFEFF6FF),
                                    value: '$_missionsJour',
                                    label: 'Missions',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Gains
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.account_balance_wallet_outlined,
                                    iconColor: const Color(0xFFEA580C),
                                    iconBg: const Color(0xFFFFF7ED),
                                    value: '${_currencyFormat.format(_revenusJour)} F',
                                    label: 'Gains',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Note
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.star_rounded,
                                    iconColor: const Color(0xFF0066FF),
                                    iconBg: const Color(0xFFEFF6FF),
                                    value: _noteMoyenne.toStringAsFixed(1),
                                    label: 'Note',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Section : Actions rapides
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F2C59),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Actions rapides',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Carte Action 1 : Missions disponibles
                            _buildActionCard(
                              icon: Icons.format_list_bulleted_rounded,
                              iconColor: const Color(0xFF0066FF),
                              iconBg: const Color(0xFFEFF6FF),
                              title: 'Missions disponibles',
                              subtitle: 'Trouver de nouvelles courses à livrer',
                              onTap: () => context.go('/livreur/missions'),
                            ),

                            const SizedBox(height: 12),

                            // Carte Action 2 : Historique des courses
                            _buildActionCard(
                              icon: Icons.history_rounded,
                              iconColor: const Color(0xFF16A34A),
                              iconBg: const Color(0xFFDCFCE7),
                              title: 'Historique des courses',
                              subtitle: 'Détail des livraisons et gains de la semaine',
                              onTap: () => context.go('/livreur/historique'),
                            ),

                            const SizedBox(height: 24),

                            // Slogan et skyline bas de page
                            Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'Ensemble pour une ville mieux servie',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontStyle: FontStyle.italic,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 90,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEA580C),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            Opacity(
                              opacity: 0.65,
                              child: Image.asset(
                                'assets/images/city_skyline_footer.png',
                                width: size.width,
                                fit: BoxFit.fitWidth,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: const GazeoBottomNav(
          currentIndex: 0,
          role: GazeoNavRole.livreur,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2C59).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F2C59),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2C59).withValues(alpha: 0.06),
              blurRadius: 14,
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
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF0066FF),
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitOrSwitchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Espace Livreur GAZEO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F2C59),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Souhaitez-vous changer de compte ou quitter ?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/choix-compte');
                },
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                label: const Text(
                  'Changer de profil',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Rester en mode Livreur'),
            ),
          ],
        ),
      ),
    );
  }
}
