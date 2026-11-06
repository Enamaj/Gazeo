import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/depot.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  final AuthService _authService = AuthService();

  // URL personnalisée via argument build/run (ex: --dart-define=API_URL=http://192.168.100.147:8000)
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  // URL de production officielle GAZEO déployée sur Railway
  static const String prodApiUrl = 'https://gazeo-production.up.railway.app';

  // URL de l'API : utilise la production Railway par défaut pour connecter tous les appareils réels
  static String get baseUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    return prodApiUrl;
  }

  ApiService._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Sécurité OWASP : Validation stricte des certificats SSL/TLS en environnement distant / HTTPS
    if (!kIsWeb && dio.httpClientAdapter is IOHttpClientAdapter) {
      (dio.httpClientAdapter as IOHttpClientAdapter).validateCertificate =
          (certificate, host, port) {
            if (host.contains('gazeo.cm') || host.contains('railway.app')) {
              return certificate != null;
            }
            return true;
          };
    }

    // Intercepteur pour injecter le token JWT si disponible
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // =========================================================================
  // Authentification & Gestion des Comptes
  // =========================================================================

  /// Connexion avec numéro camerounais et mot de passe
  Future<Map<String, dynamic>> connexion({
    required String telephone,
    required String password,
  }) async {
    final response = await dio.post(
      '/auth/connexion/',
      data: {'telephone': telephone, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final user = data['user'] as Map<String, dynamic>?;

    if (tokens == null) {
      throw const FormatException(
        'La réponse de connexion ne contient pas de jetons.',
      );
    }
    await _authService.saveTokens(
      access: tokens['access'] as String? ?? '',
      refresh: tokens['refresh'] as String? ?? '',
      role: user?['role'] as String? ?? 'CLIENT',
      phone: user?['telephone'] as String? ?? telephone,
    );
    return data;
  }

  /// Inscription d'un nouvel utilisateur
  Future<Map<String, dynamic>> inscription({
    required String telephone,
    required String password,
    required String role,
  }) async {
    final response = await dio.post(
      '/auth/inscription/',
      data: {'telephone': telephone, 'password': password, 'role': role},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Vérification du code OTP SMS et activation
  Future<Map<String, dynamic>> verifierOTP({
    required String telephone,
    required String otpCode,
  }) async {
    final response = await dio.post(
      '/auth/verifier-otp/',
      data: {'telephone': telephone, 'otp_code': otpCode},
    );

    final data = response.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final user = data['user'] as Map<String, dynamic>?;
    if (tokens == null) {
      throw const FormatException(
        'La validation OTP ne contient pas de jetons.',
      );
    }
    await _authService.saveTokens(
      access: tokens['access'] as String? ?? '',
      refresh: tokens['refresh'] as String? ?? '',
      role: user?['role'] as String? ?? 'CLIENT',
      phone: user?['telephone'] as String? ?? telephone,
    );
    return data;
  }

  /// Déconnexion de l'utilisateur
  Future<void> deconnexion() async {
    try {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await dio.post('/auth/deconnexion/', data: {'refresh': refreshToken});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Info deconnexion: $e');
    } finally {
      await _authService.logout();
    }
  }

  /// Profil de l'utilisateur connecté
  Future<Map<String, dynamic>?> getProfil() async {
    final response = await dio.get('/auth/profil/');
    return response.data as Map<String, dynamic>?;
  }

  // =========================================================================
  // Dépôts de gaz & Localisation
  // =========================================================================

  /// Récupère les dépôts proches depuis le catalogue réel du backend.
  Future<List<DepotModel>> getDepotsProches({
    required double lat,
    required double lon,
    double rayon = 5000,
    String? marque,
    bool stockUniquement = false,
    String? quartier,
  }) async {
    final queryParams = <String, dynamic>{
      'lat': lat,
      'lon': lon,
      'rayon': rayon,
      'stock_uniquement': stockUniquement,
    };
    if (marque != null && marque.isNotEmpty) {
      queryParams['marque'] = marque;
    }
    if (quartier != null && quartier.isNotEmpty) {
      queryParams['quartier'] = quartier;
    }

    final response = await dio.get(
      '/depots/proches/',
      queryParameters: queryParams,
    );
    final payload = response.data as Map<String, dynamic>;
    final depots = payload['depots'] as List<dynamic>? ?? [];
    return depots
        .map((item) => DepotModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Récupère la fiche détaillée d'un dépôt
  Future<Map<String, dynamic>> getDepotDetail(int id) async {
    final response = await dio.get('/depots/$id/');
    return response.data as Map<String, dynamic>;
  }

  /// Récupère les avis clients d'un dépôt
  Future<List<dynamic>> getDepotAvis(int id) async {
    final response = await dio.get('/depots/$id/avis/');
    return response.data['avis'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> creerCommande({
    required int depotId,
    required int quantite6kg,
    required int quantite12kg,
    required String adresseLivraison,
    required double latitudeLivraison,
    required double longitudeLivraison,
  }) async {
    final response = await dio.post(
      '/commandes/creer/',
      data: {
        'depot_id': depotId,
        'quantite_6kg': quantite6kg,
        'quantite_12kg': quantite12kg,
        'adresse_livraison': adresseLivraison,
        'latitude_livraison': latitudeLivraison,
        'longitude_livraison': longitudeLivraison,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> initierPaiement({
    required int commandeId,
    String? telephone,
  }) async {
    final response = await dio.post(
      '/paiements/initier/',
      data: {
        'commande_id': commandeId,
        if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> annulerCommande(int commandeId) async {
    await dio.put('/commandes/$commandeId/annuler/', data: {});
  }

  Future<List<Map<String, dynamic>>> getMesCommandes() async {
    final response = await dio.get('/commandes/mes-commandes/');
    final commandes =
        (response.data as Map<String, dynamic>)['commandes']
            as List<dynamic>? ??
        [];
    return commandes
        .map((commande) => Map<String, dynamic>.from(commande as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getCommandeClient(int commandeId) async {
    final commandes = await getMesCommandes();
    return commandes.firstWhere(
      (commande) => commande['id'] == commandeId,
      orElse: () =>
          throw StateError('Commande introuvable dans votre historique.'),
    );
  }

  Future<List<dynamic>> getMesNotifications() async {
    final response = await dio.get('/notifications/mes-notifications/');
    return response.data as List<dynamic>;
  }

  // =========================================================================
  // Espace Gérant
  // =========================================================================

  Future<Map<String, dynamic>> getGerantMonDepot() async {
    final response = await dio.get('/gerants/mon-depot/');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mettreAJourTarifsGerant({
    required double prix6kg,
    required double prix12kg,
  }) async {
    final response = await dio.put(
      '/gerants/mon-depot/',
      data: {'prix_6kg': prix6kg, 'prix_12kg': prix12kg},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mettreAJourStockGerant({
    required int stock6kg,
    required int stock12kg,
  }) async {
    final response = await dio.post(
      '/gerants/mon-depot/stock/',
      data: {'stock_6kg': stock6kg, 'stock_12kg': stock12kg},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getGerantCommandes() async {
    final response = await dio.get('/gerants/commandes/');
    final commandes = response.data['commandes'] as List<dynamic>? ?? [];
    return commandes
        .map((commande) => Map<String, dynamic>.from(commande as Map))
        .toList();
  }

  Future<Map<String, dynamic>> accepterCommandeGerant(int commandeId) async {
    final response = await dio.put(
      '/commandes/$commandeId/accepter/',
      data: {},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGerantKycStatut() async {
    final response = await dio.get('/gerants/kyc/statut/');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enregistrerProfilDepotGerant({
    required Map<String, dynamic> profil,
    PlatformFile? imageDepot,
    required bool creation,
  }) async {
    final fields = <MapEntry<String, String>>[];
    for (final entry in profil.entries) {
      if (entry.key == 'marques_disponibles') {
        for (final marque in entry.value as List<String>) {
          fields.add(MapEntry('marques_disponibles', marque));
        }
      } else {
        fields.add(MapEntry(entry.key, entry.value.toString()));
      }
    }
    final files = <MapEntry<String, MultipartFile>>[];
    if (imageDepot != null) {
      final bytes = await imageDepot.readAsBytes();
      if (bytes.isEmpty) {
        throw FormatException(
          'Le fichier ${imageDepot.name} ne peut pas être lu.',
        );
      }
      files.add(
        MapEntry(
          'image_depot',
          MultipartFile.fromBytes(bytes, filename: imageDepot.name),
        ),
      );
    }
    final formData = FormData()
      ..fields.addAll(fields)
      ..files.addAll(files);
    final response = creation
        ? await dio.post(
            '/gerants/mon-depot/',
            data: formData,
            options: Options(contentType: 'multipart/form-data'),
          )
        : await dio.put(
            '/gerants/mon-depot/',
            data: formData,
            options: Options(contentType: 'multipart/form-data'),
          );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> notifierRetourStockGerant() async {
    final response = await dio.post('/gerants/mon-depot/notifier-stock/');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> soumettreDossierKycGerant({
    required PlatformFile cniRecto,
    required PlatformFile cniVerso,
    required PlatformFile photoDepot,
    required PlatformFile photoDepotInterieur,
    required PlatformFile documentCommercial,
  }) async {
    final files = <String, PlatformFile>{
      'cni_recto': cniRecto,
      'cni_verso': cniVerso,
      'photo_depot': photoDepot,
      'photo_depot_interieur': photoDepotInterieur,
      'document_commercial': documentCommercial,
    };
    final data = <String, MultipartFile>{};
    for (final entry in files.entries) {
      final bytes = await entry.value.readAsBytes();
      if (bytes.isEmpty) {
        throw FormatException(
          'Le fichier ${entry.value.name} ne peut pas être lu.',
        );
      }
      data[entry.key] = MultipartFile.fromBytes(
        bytes,
        filename: entry.value.name,
      );
    }

    final response = await dio.post(
      '/gerants/kyc/soumettre/',
      data: FormData.fromMap(data),
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  // =========================================================================
  // Méthodes Interface Livreur
  // =========================================================================

  Future<Map<String, dynamic>> getLivreurTableauDeBord() async {
    final response = await dio.get('/livreurs/tableau-de-bord/');
    return response.data as Map<String, dynamic>;
  }

  Future<bool> toggleDisponibilite({bool? estDisponible}) async {
    final data = estDisponible != null
        ? {'est_disponible': estDisponible}
        : <String, dynamic>{};
    final response = await dio.put('/livreurs/disponibilite/', data: data);
    return response.data['est_disponible'] as bool? ?? true;
  }

  Future<List<dynamic>> getMissionsDisponibles() async {
    final response = await dio.get('/livreurs/missions/');
    return response.data['missions'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> accepterMission(int commandeId) async {
    final response = await dio.put(
      '/commandes/$commandeId/accepter/',
      data: {},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recupererStock(int commandeId) async {
    final response = await dio.post(
      '/commandes/$commandeId/recuperer-stock/',
      data: {},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmerLivraison(
    int commandeId,
    String codeOtp,
  ) async {
    final response = await dio.put(
      '/commandes/$commandeId/confirmer/',
      data: {'code_otp': codeOtp},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLivreurHistorique() async {
    final response = await dio.get('/livreurs/historique/');
    return response.data as Map<String, dynamic>;
  }

  Future<void> mettreAJourPosition(
    int commandeId,
    double lat,
    double lon,
  ) async {
    await dio.post(
      '/livraisons/$commandeId/position/',
      data: {'latitude': lat, 'longitude': lon},
    );
  }

  Future<void> enregistrerFCMToken(
    String token, {
    String deviceType = 'android',
  }) async {
    await dio.post(
      '/notifications/token/',
      data: {'token': token, 'device_type': deviceType},
    );
  }
}
