import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isRoadNetwork;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isRoadNetwork,
  });

  String get formattedDistance {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return '${h}h ${m}m';
  }
}

class RoutingService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {'Accept': 'application/json', 'User-Agent': 'GAZEO-Mobile/1.0'},
    ),
  );

  /// Calcule l'itinéraire routier entre le point de départ et la destination
  static Future<RouteResult> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List?;

          if (coords != null && coords.isNotEmpty) {
            final points = coords.map<LatLng>((c) {
              final lon = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lon);
            }).toList();

            final distanceMetres = (firstRoute['distance'] as num?)?.toDouble();
            final durationSec = (firstRoute['duration'] as num?)?.toDouble();
            if (distanceMetres == null || durationSec == null) {
              throw const FormatException('Réponse itinéraire incomplète.');
            }

            final distKm = distanceMetres / 1000.0;
            final durMin = (durationSec / 60.0).round();

            if (kDebugMode) {
              debugPrint(
                '[RoutingService] OSRM Itinéraire reçu : ${points.length} points, ${distKm.toStringAsFixed(1)}km, $durMin min',
              );
            }

            return RouteResult(
              points: points,
              distanceKm: distKm,
              durationMinutes: durMin < 2 ? 2 : durMin,
              isRoadNetwork: true,
            );
          }
        }
      }
      throw const FormatException('Aucun itinéraire routier disponible.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RoutingService] Itinéraire routier indisponible : $e');
      }
      throw StateError(
        'Impossible de calculer un itinéraire routier actuellement. '
        'Vérifiez votre connexion puis réessayez.',
      );
    }
  }
}
