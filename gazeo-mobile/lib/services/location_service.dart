import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Limites géographiques strictes du Cameroun
  static const double minCameroonLat = 1.6;
  static const double maxCameroonLat = 13.1;
  static const double minCameroonLon = 8.4;
  static const double maxCameroonLon = 16.2;

  // Coordonnées de référence : Centre de Yaoundé (Poste Centrale)
  static const LatLng defaultYaounde = LatLng(3.8667, 11.5167);

  // Quartiers populaires de Yaoundé pour tests et navigation rapide
  static const Map<String, LatLng> yaoundeHubs = {
    'Poste Centrale (Centre)': LatLng(3.8667, 11.5167),
    'Bastos (Ambassades)': LatLng(3.8950, 11.5130),
    'Melen (Université)': LatLng(3.8580, 11.4980),
    'Omnisports (Stade Ahmadou)': LatLng(3.8820, 11.5390),
    'Mokolo (Grand Marché)': LatLng(3.8740, 11.5030),
    'Biyem-Assi': LatLng(3.8340, 11.4880),
  };

  // Position forcée manuellement pour les tests sur émulateur
  static LatLng? _forcedLocation;

  static void setForcedLocation(LatLng? loc) {
    _forcedLocation = loc;
  }

  static LatLng? get forcedLocation => _forcedLocation;

  static Future<LatLng> getCurrentPositionForDelivery() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return defaultYaounde;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return defaultYaounde;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (isWithinCameroon(position.latitude, position.longitude)) {
        return LatLng(position.latitude, position.longitude);
      }
      return defaultYaounde;
    } catch (_) {
      return defaultYaounde;
    }
  }

  /// Vérifie si une coordonnée GPS se situe bien sur le territoire camerounais
  static bool isWithinCameroon(double lat, double lon) {
    return lat >= minCameroonLat &&
        lat <= maxCameroonLat &&
        lon >= minCameroonLon &&
        lon <= maxCameroonLon;
  }

  /// Récupère une position GPS vérifiée sur le territoire camerounais.
  static Future<LatLng> getCurrentPosition() async {
    if (_forcedLocation != null) {
      if (kDebugMode) {
        debugPrint(
          '[LocationService] Utilisation de la position forcée : $_forcedLocation',
        );
      }
      return _forcedLocation!;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Service GPS désactivé. Repli Yaoundé.');
        return defaultYaounde;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permission GPS non accordée. Repli Yaoundé.');
        return defaultYaounde;
      }

      // 1. Position en cache ultra-rapide (<50ms)
      Position? position = await Geolocator.getLastKnownPosition();

      // 2. Acquisition fraîche si aucun cache
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (isWithinCameroon(position.latitude, position.longitude)) {
        return LatLng(position.latitude, position.longitude);
      }

      debugPrint(
        '[LocationService] Coordonnées (${position.latitude}, ${position.longitude}) hors Cameroun. Centrage Yaoundé.',
      );
      return defaultYaounde;
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationService] Erreur GPS: $e -> Repli Yaoundé.');
      return defaultYaounde;
    }
  }

  /// Calcule la distance à vol d'oiseau en kilomètres entre deux points
  static double distanceBetweenKm(LatLng p1, LatLng p2) {
    final distanceMetres = Geolocator.distanceBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
    return (distanceMetres / 1000.0);
  }

  /// Estime le temps de trajet en moto à Yaoundé (vitesse moyenne 22 km/h + 3 min préparation)
  static int estimateMotoMinutes(double distanceKm) {
    if (distanceKm <= 0) return 2;
    final minutes = ((distanceKm / 22.0) * 60).round() + 3;
    return minutes < 3 ? 3 : minutes;
  }
}
