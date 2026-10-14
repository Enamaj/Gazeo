import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Coordonnées de repli : Centre de Yaoundé (Poste Centrale)
  static const LatLng defaultYaounde = LatLng(3.8667, 11.5167);

  static Future<LatLng> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Service de localisation désactivé, utilisation de Yaoundé');
        return defaultYaounde;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Permission refusée, utilisation de Yaoundé');
          return defaultYaounde;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permission refusée définitivement, utilisation de Yaoundé');
        return defaultYaounde;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('[LocationService] Exception localisation: $e');
      return defaultYaounde;
    }
  }
}

