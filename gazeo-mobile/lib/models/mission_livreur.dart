class MissionLivreur {
  final int id;
  final int depotId;
  final String depotNom;
  final String depotAdresse;
  final String depotQuartier;
  final String depotTelephone;
  final double? depotLatitude;
  final double? depotLongitude;
  final String clientTelephone;
  final String clientNom;
  final int quantite6kg;
  final int quantite12kg;
  final double montantTotal;
  final double fraisLivraison;
  final String statut;
  final String adresseLivraison;
  final double latitudeLivraison;
  final double longitudeLivraison;
  final String? codeConfirmation;
  final DateTime createdAt;

  MissionLivreur({
    required this.id,
    required this.depotId,
    required this.depotNom,
    required this.depotAdresse,
    required this.depotQuartier,
    required this.depotTelephone,
    this.depotLatitude,
    this.depotLongitude,
    required this.clientTelephone,
    required this.clientNom,
    required this.quantite6kg,
    required this.quantite12kg,
    required this.montantTotal,
    required this.fraisLivraison,
    required this.statut,
    required this.adresseLivraison,
    required this.latitudeLivraison,
    required this.longitudeLivraison,
    this.codeConfirmation,
    required this.createdAt,
  });

  factory MissionLivreur.fromJson(Map<String, dynamic> json) {
    return MissionLivreur(
      id: json['id'],
      depotId: json['depot_id'] ?? 0,
      depotNom: json['depot_nom'] ?? 'Dépôt Gaz',
      depotAdresse: json['depot_adresse'] ?? '',
      depotQuartier: json['depot_quartier'] ?? '',
      depotTelephone: json['depot_telephone'] ?? '',
      depotLatitude: json['depot_latitude'] != null ? (json['depot_latitude'] as num).toDouble() : null,
      depotLongitude: json['depot_longitude'] != null ? (json['depot_longitude'] as num).toDouble() : null,
      clientTelephone: json['client_telephone'] ?? '',
      clientNom: json['client_nom'] ?? '',
      quantite6kg: json['quantite_6kg'] ?? 0,
      quantite12kg: json['quantite_12kg'] ?? 0,
      montantTotal: double.tryParse(json['montant_total']?.toString() ?? '0') ?? 0.0,
      fraisLivraison: double.tryParse(json['frais_livraison']?.toString() ?? '0') ?? 0.0,
      statut: json['statut'] ?? '',
      adresseLivraison: json['adresse_livraison'] ?? '',
      latitudeLivraison: (json['latitude_livraison'] as num?)?.toDouble() ?? 3.8667,
      longitudeLivraison: (json['longitude_livraison'] as num?)?.toDouble() ?? 11.5167,
      codeConfirmation: json['code_confirmation'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
