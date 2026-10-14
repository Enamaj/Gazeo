import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/mission_livreur.dart';
import '../../services/api_service.dart';

class ListeMissionsScreen extends StatefulWidget {
  const ListeMissionsScreen({super.key});

  @override
  State<ListeMissionsScreen> createState() => _ListeMissionsScreenState();
}

class _ListeMissionsScreenState extends State<ListeMissionsScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  bool _isLoading = true;
  List<MissionLivreur> _missions = [];
  String? _errorMessage;
  int? _acceptingId;

  @override
  void initState() {
    super.initState();
    _chargerMissions();
  }

  Future<void> _chargerMissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.getMissionsDisponibles();
      if (mounted) {
        setState(() {
          _missions = list.map((item) => MissionLivreur.fromJson(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de récupérer les missions disponibles.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _accepterMission(MissionLivreur mission) async {
    setState(() => _acceptingId = mission.id);

    try {
      await _apiService.accepterMission(mission.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Mission #${mission.id} acceptée ! Rendez-vous au dépôt ${mission.depotNom}."),
            backgroundColor: Colors.green[700],
          ),
        );
        // Naviguer vers l'écran de mission active
        context.pushReplacement('/livreur/mission-active/${mission.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acceptingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'acceptation. La course a peut-être déjà été prise."),
            backgroundColor: Colors.red,
          ),
        );
        _chargerMissions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Missions disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerMissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerMissions,
              child: _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _chargerMissions,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _missions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 56, color: Colors.green[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune mission en attente',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Toutes les commandes à proximité sont pourvues.\nRestez en ligne, de nouvelles commandes arrivent !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _missions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {

                            final mission = _missions[index];
                            final isAccepting = _acceptingId == mission.id;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Entête de la course
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),

                                          child: Text(
                                            'Course #${mission.id}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A8A),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '+${_currencyFormat.format(mission.fraisLivraison)} FCFA',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Étape 1 : Collecte au dépôt
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.storefront, color: Colors.blue, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Collecte : ${mission.depotNom}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              Text(
                                                mission.depotAdresse.isNotEmpty ? mission.depotAdresse : mission.depotQuartier,
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 9),
                                      child: SizedBox(
                                        height: 16,
                                        child: VerticalDivider(thickness: 2, color: Colors.grey),
                                      ),
                                    ),

                                    // Étape 2 : Livraison au client
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Livraison client',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              Text(
                                                mission.adresseLivraison,
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),

                                    // Détail bouteilles et bouton
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            spacing: 6,
                                            children: [
                                              if (mission.quantite6kg > 0)
                                                Chip(
                                                  label: Text('${mission.quantite6kg} x 6kg', style: const TextStyle(fontSize: 11)),
                                                  backgroundColor: Colors.grey[100],
                                                  padding: EdgeInsets.zero,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              if (mission.quantite12kg > 0)
                                                Chip(
                                                  label: Text('${mission.quantite12kg} x 12.5kg', style: const TextStyle(fontSize: 11)),
                                                  backgroundColor: Colors.grey[100],
                                                  padding: EdgeInsets.zero,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: isAccepting
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.check, size: 18),
                                          label: const Text('Accepter la mission'),
                                          onPressed: isAccepting ? null : () => _accepterMission(mission),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
