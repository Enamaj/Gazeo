class DepotModel {
  final int id;
  final String nom;
  final String adresse;
  final String quartier;
  final String telephone;
  final String marque;
  final int stock6kg;
  final int stock12kg;
  final int stockDisponible;
  final double prix6kg;
  final double prix12kg;
  final double latitude;
  final double longitude;
  final double? distanceMetres;
  final double? distanceKm;
  final double noteMoyenne;
  final String statutKyc;
  final bool estActif;

  DepotModel({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.quartier,
    required this.telephone,
    required this.marque,
    required this.stock6kg,
    required this.stock12kg,
    required this.stockDisponible,
    required this.prix6kg,
    required this.prix12kg,
    required this.latitude,
    required this.longitude,
    this.distanceMetres,
    this.distanceKm,
    required this.noteMoyenne,
    required this.statutKyc,
    required this.estActif,
  });

  factory DepotModel.fromJson(Map<String, dynamic> json) {
    return DepotModel(
      id: json['id'] as int,
      nom: json['nom'] as String? ?? 'Dépôt de gaz',
      adresse: json['adresse'] as String? ?? '',
      quartier: json['quartier'] as String? ?? 'Yaoundé',
      telephone: json['telephone'] as String? ?? '',
      marque: json['marque'] as String? ?? 'TRADEX',
      stock6kg: json['stock_6kg'] as int? ?? 0,
      stock12kg: json['stock_12kg'] as int? ?? 0,
      stockDisponible: json['stock_disponible'] as int? ?? 0,
      prix6kg: double.tryParse(json['prix_6kg']?.toString() ?? '3000') ?? 3000.0,
      prix12kg: double.tryParse(json['prix_12kg']?.toString() ?? '6500') ?? 6500.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 3.8667,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 11.5167,
      distanceMetres: (json['distance_metres'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      noteMoyenne: (json['note_moyenne'] as num?)?.toDouble() ?? 5.0,
      statutKyc: json['statut_kyc'] as String? ?? 'VALIDE',
      estActif: json['est_actif'] as bool? ?? true,
    );
  }

  bool get enRupture => stockDisponible <= 0;
  bool get stockFaible => stockDisponible > 0 && stockDisponible <= 5;
}

