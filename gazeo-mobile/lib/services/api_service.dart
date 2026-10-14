import 'dart:io';
import 'package:dio/dio.dart';
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
      debugPrint('[ApiService] Erreur getDepotsProches: $e');
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
}

