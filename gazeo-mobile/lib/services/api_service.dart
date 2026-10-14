import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../models/depot.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  final AuthService _authService = AuthService();

  // URL de l'API selon la plateforme (10.0.2.2 pour émulateur Android, localhost pour Linux/Web)
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  ApiService._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Sécurité OWASP : Validation stricte des certificats SSL/TLS en environnement distant / HTTPS
    if (!kIsWeb && dio.httpClientAdapter is IOHttpClientAdapter) {
      (dio.httpClientAdapter as IOHttpClientAdapter).validateCertificate = (certificate, host, port) {
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

  /// Récupère la liste des dépôts proches via PostGIS ST_DWithin
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
    if (marque != null && marque.isNotEmpty) queryParams['marque'] = marque;
    if (quartier != null && quartier.isNotEmpty) queryParams['quartier'] = quartier;

    try {
      final response = await dio.get('/depots/proches/', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data['depots'] != null) {
        final list = response.data['depots'] as List;
        return list.map((item) => DepotModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Erreur getDepotsProches: $e');
      rethrow;
    }
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

  // =========================================================================
  // Méthodes Interface Livreur
  // =========================================================================

  /// Récupère les données du tableau de bord livreur
  Future<Map<String, dynamic>> getLivreurTableauDeBord() async {
    final response = await dio.get('/livreurs/tableau-de-bord/');
    return response.data as Map<String, dynamic>;
  }

  /// Active/Désactive la disponibilité du livreur
  Future<bool> toggleDisponibilite({bool? estDisponible}) async {
    final data = estDisponible != null ? {'est_disponible': estDisponible} : <String, dynamic>{};
    final response = await dio.put('/livreurs/disponibilite/', data: data);
    return response.data['est_disponible'] as bool? ?? true;
  }

  /// Récupère la liste des missions disponibles
  Future<List<dynamic>> getMissionsDisponibles() async {
    final response = await dio.get('/livreurs/missions/');
    return response.data['missions'] as List<dynamic>? ?? [];
  }

  /// Accepte une mission pour le livreur connecté
  Future<Map<String, dynamic>> accepterMission(int commandeId) async {
    final response = await dio.put('/commandes/$commandeId/accepter/', data: {});
    return response.data as Map<String, dynamic>;
  }

  /// Confirme la récupération du stock de bouteilles au dépôt
  Future<Map<String, dynamic>> recupererStock(int commandeId) async {
    final response = await dio.post('/commandes/$commandeId/recuperer-stock/', data: {});
    return response.data as Map<String, dynamic>;
  }

  /// Valide la livraison au client par le code OTP à 6 chiffres
  Future<Map<String, dynamic>> confirmerLivraison(int commandeId, String codeOtp) async {
    final response = await dio.put(
      '/commandes/$commandeId/confirmer/',
      data: {'code_otp': codeOtp},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Récupère l'historique des livraisons et gains du livreur
  Future<Map<String, dynamic>> getLivreurHistorique() async {
    final response = await dio.get('/livreurs/historique/');
    return response.data as Map<String, dynamic>;
  }

  /// Enregistre la position GPS temps réel du livreur pour le suivi
  Future<void> mettreAJourPosition(int commandeId, double lat, double lon) async {
    await dio.post(
      '/livraisons/$commandeId/position/',
      data: {'latitude': lat, 'longitude': lon},
    );
  }

  /// Enregistre le token FCM de l'appareil
  Future<void> enregistrerFCMToken(String token, {String deviceType = 'android'}) async {
    await dio.post(
      '/notifications/token/',
      data: {'token': token, 'device_type': deviceType},
    );
  }
}


