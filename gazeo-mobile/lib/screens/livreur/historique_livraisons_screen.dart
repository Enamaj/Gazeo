import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mission_livreur.dart';
import '../../services/api_service.dart';

class HistoriqueLivraisonsScreen extends StatefulWidget {
  const HistoriqueLivraisonsScreen({super.key});

  @override
  State<HistoriqueLivraisonsScreen> createState() => _HistoriqueLivraisonsScreenState();
}

class _HistoriqueLivraisonsScreenState extends State<HistoriqueLivraisonsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  bool _isLoading = true;
  String? _errorMessage;
  int _totalMissions = 0;
  double _totalRevenus = 0.0;
  List<MissionLivreur> _historique = [];

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.getLivreurHistorique();
      if (mounted) {
        final list = (data['historique'] as List<dynamic>? ?? []);
        setState(() {
          _totalMissions = data['total_missions'] ?? 0;
          _totalRevenus = (data['total_revenus'] as num?)?.toDouble() ?? 0.0;
          _historique = list.map((item) => MissionLivreur.fromJson(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de récupérer l'historique des livraisons.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Historique des courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerHistorique,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Carte de synthèse des gains
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total des gains cumulés',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_currencyFormat.format(_totalRevenus)} FCFA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_totalMissions livraisons',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),

                              child: const Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Note moyenne: 4.8 / 5',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Détail des courses réalisées',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 12),

                  if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    )
                  else if (_historique.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune livraison terminée pour le moment',
                              style: TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._historique.map((mission) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Course #${mission.id}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '+${_currencyFormat.format(mission.fraisLivraison)} FCFA',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateFormat.format(mission.createdAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.storefront, size: 16, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      mission.depotNom,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      mission.adresseLivraison,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
