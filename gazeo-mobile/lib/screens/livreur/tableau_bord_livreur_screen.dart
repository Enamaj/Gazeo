import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/mission_livreur.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class TableauBordLivreurScreen extends StatefulWidget {
  const TableauBordLivreurScreen({super.key});

  @override
  State<TableauBordLivreurScreen> createState() => _TableauBordLivreurScreenState();
}

class _TableauBordLivreurScreenState extends State<TableauBordLivreurScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  bool _isLoading = true;
  bool _estDisponible = true;
  int _missionsJour = 0;
  double _revenusJour = 0.0;
  double _noteMoyenne = 5.0;
  MissionLivreur? _missionActive;
  String? _userPhone;
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
      final data = await _apiService.getLivreurTableauDeBord();

      if (mounted) {
        setState(() {
          _userPhone = phone ?? 'Livreur GAZEO';
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
          _errorMessage = "Impossible de charger le tableau de bord. Vérifiez votre connexion.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDisponibilite(bool value) async {
    setState(() => _estDisponible = value);
    try {
      final newState = await _apiService.toggleDisponibilite(estDisponible: value);
      if (mounted) {
        setState(() => _estDisponible = newState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _estDisponible ? "Vous êtes EN SERVICE. Prêt à recevoir des courses !" : "Vous êtes HORS LIGNE.",
            ),
            backgroundColor: _estDisponible ? Colors.green[700] : Colors.grey[800],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estDisponible = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de la mise à jour de disponibilité."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Espace Livreur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Vue Carte Client',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: Colors.red[800])),
                    ),

                  // Carte Profil & Toggle Disponibilité
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                child: const Icon(Icons.two_wheeler, color: Color(0xFF1E3A8A), size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Livreur Partenaire',
                                      style: TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                    Text(
                                      _userPhone ?? '+237 ...',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _estDisponible ? Colors.green[100] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _estDisponible ? 'EN LIGNE' : 'HORS LIGNE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _estDisponible ? Colors.green[800] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Disponibilité pour livrer',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              _estDisponible
                                  ? 'Vous recevez les alertes de nouvelles missions'
                                  : 'Activez pour recevoir de nouvelles courses',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _estDisponible,
                            activeTrackColor: Colors.green[700],
                            onChanged: _toggleDisponibilite,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Alerte Mission Active en cours
                  if (_missionActive != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[400],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'MISSION ACTIVE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_currencyFormat.format(_missionActive!.fraisLivraison)} FCFA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Course #${_missionActive!.id} • ${_missionActive!.depotNom}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Destination : ${_missionActive!.adresseLivraison}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[400],
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.navigation),
                              label: const Text('Reprendre la mission en cours', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                context.push('/livreur/mission-active/${_missionActive!.id}');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Statistiques du jour
                  const Text(
                    "Aujourd'hui à Yaoundé",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          titre: 'Missions',
                          valeur: '$_missionsJour',
                          icone: Icons.check_circle_outline,
                          couleur: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          titre: 'Gains',
                          valeur: '${_currencyFormat.format(_revenusJour)} F',
                          icone: Icons.account_balance_wallet_outlined,
                          couleur: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          titre: 'Note',
                          valeur: '⭐ $_noteMoyenne',
                          icone: Icons.star_outline,
                          couleur: Colors.amber,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Actions rapides
                  const Text(
                    'Actions rapides',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEEF2FF),
                      child: Icon(Icons.list_alt, color: Color(0xFF1E3A8A)),
                    ),
                    title: const Text('Missions disponibles', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Trouver de nouvelles courses à livrer'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/livreur/missions'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECFDF5),
                      child: Icon(Icons.history, color: Colors.green),
                    ),
                    title: const Text('Historique des courses', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Détail des livraisons et gains de la semaine'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/livreur/historique'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String titre;
  final String valeur;
  final IconData icone;
  final MaterialColor couleur;

  const _StatCard({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icone, color: couleur[700], size: 24),
            const SizedBox(height: 6),
            Text(
              valeur,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur[900]),
            ),
            const SizedBox(height: 4),
            Text(
              titre,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
