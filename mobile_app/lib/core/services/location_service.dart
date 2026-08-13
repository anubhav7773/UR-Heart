import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../network/api_client.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;
  LocationService._internal();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  /// Requests GPS location permissions and fetches active device coordinates.
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('GPS location services are disabled on device.');
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('GPS location permissions denied by user.');
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('GPS location permissions are permanently denied.');
        }
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (_currentPosition != null) {
        if (kDebugMode) {
          print('GPS Position Acquired: Lat=${_currentPosition!.latitude}, Lng=${_currentPosition!.longitude}');
        }
        // Update user's current GPS location on backend
        await _syncLocationToBackend(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      return _currentPosition;
    } catch (e) {
      if (kDebugMode) {
        print('GPS Location Exception: $e');
      }
      return null;
    }
  }

  Future<Position?> updateUserLocation() async {
    final pos = await getCurrentLocation();
    if (pos != null) {
      try {
        await ApiClient.instance.dio.post('/users/location', data: {
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
      } catch (_) {}
    }
    return pos;
  }

  Future<void> _syncLocationToBackend(double lat, double lng) async {
    try {
      await ApiClient.instance.putProfile({
        'latitude': lat,
        'longitude': lng,
      });
      await ApiClient.instance.dio.post('/users/location', data: {
        'lat': lat,
        'lng': lng,
      });
      if (kDebugMode) {
        print('User GPS location synced to backend profile.');
      }
    } catch (e) {
      // Non-blocking location update fallback
    }
  }
}
