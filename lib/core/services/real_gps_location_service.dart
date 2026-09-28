import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_logger_service.dart';

class GpsLocationResult {
  final bool isSuccess;
  final String formattedLocation;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isMocked;
  final String? errorMessage;

  const GpsLocationResult({
    required this.isSuccess,
    required this.formattedLocation,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isMocked,
    this.errorMessage,
  });

  factory GpsLocationResult.failure(String message) {
    return GpsLocationResult(
      isSuccess: false,
      formattedLocation: 'Location Unavailable',
      latitude: 0.0,
      longitude: 0.0,
      accuracyMeters: 0.0,
      isMocked: false,
      errorMessage: message,
    );
  }
}

/// Production-Grade Anti-Fraud Real Hardware GPS Service
class RealGpsLocationService {
  const RealGpsLocationService._();

  /// Obtains authentic hardware GPS coordinates and reverse-geocodes locality
  static Future<GpsLocationResult> acquireRealHardwareGps() async {
    try {
      // 1. Check if location services are enabled on device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return GpsLocationResult.failure(
          'Location services are disabled. Please turn on GPS in device settings.',
        );
      }

      // 2. Permission Verification
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return GpsLocationResult.failure(
            'Location permission denied. Real GPS is required for authentic matching.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return GpsLocationResult.failure(
          'Location permission permanently denied. Enable permissions in App Settings.',
        );
      }

      // 3. Acquire Real Position with High Accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      // 4. Anti-Fraud: Detect Mock / Spoofed Location
      if (position.isMocked) {
        await ActivityLogger.log(
          category: 'FRAUD_ALERT',
          action: 'MOCK_GPS_DETECTED',
          details: {
            'lat': position.latitude,
            'lng': position.longitude,
            'is_mocked': true,
          },
        );
        return GpsLocationResult.failure(
          'Anti-Fraud Security: Mock or fake GPS app detected. Please use genuine device GPS.',
        );
      }

      // 5. Reverse Geocode via OpenStreetMap Nominatim
      final formattedAddress = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      // 6. Persist Real Coordinates & Formatted Name
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_location', formattedAddress);
      await prefs.setDouble('profile_gps_latitude', position.latitude);
      await prefs.setDouble('profile_gps_longitude', position.longitude);
      await prefs.setDouble('profile_gps_accuracy', position.accuracy);
      await prefs.setBool('profile_gps_verified', true);

      // 7. Stream Telemetry to Render
      await ActivityLogger.log(
        category: 'GPS',
        action: 'REAL_GPS_VERIFIED',
        details: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_meters': position.accuracy,
          'location_string': formattedAddress,
          'anti_fraud_passed': true,
        },
      );

      return GpsLocationResult(
        isSuccess: true,
        formattedLocation: formattedAddress,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        isMocked: false,
      );
    } catch (e) {
      debugPrint('[RealGpsLocationService] GPS error: $e');
      return GpsLocationResult.failure('Failed to acquire GPS: $e');
    }
  }

  static Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=14&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'UR-Heart-MindfulDating/1.0.0 (contact@sanctuary.in)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final locality = address['suburb'] ??
              address['neighbourhood'] ??
              address['residential'] ??
              address['village'] ??
              address['city_district'];
          final city = address['city'] ??
              address['town'] ??
              address['state_district'] ??
              address['county'];
          final state = address['state'];

          if (locality != null && city != null) {
            return '$locality, $city · GPS Verified';
          } else if (city != null) {
            return '$city, ${state ?? "India"} · GPS Verified';
          } else if (address['display_name'] != null) {
            final parts = (address['display_name'] as String).split(',');
            return '${parts.take(2).join(', ').trim()} · GPS Verified';
          }
        }
      }
    } catch (_) {
      // Fallback coordinate representation
    }

    return '${lat.toStringAsFixed(3)}°N, ${lon.toStringAsFixed(3)}°E · GPS Verified';
  }
}
