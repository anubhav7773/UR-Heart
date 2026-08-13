import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../network/api_client.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;
  LocationService._internal();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  String? _lastError;
  String? get lastError => _lastError;

  /// Requests GPS location permissions and fetches active device coordinates.
  Future<Position?> getCurrentLocation() async {
    _lastError = null;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError = 'Location services are disabled. Turn on GPS to see nearby people.';
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _lastError = 'Location permission was denied. Enable it to see nearby people.';
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _lastError = 'Location permission is permanently denied. Enable it in Android settings.';
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
      _lastError = 'Unable to get your current GPS location. Please try again.';
      if (kDebugMode) print('GPS Location Exception: $e');
      return null;
    }
  }

  Future<Position?> updateUserLocation() async {
    return getCurrentLocation();
  }

  Future<void> _syncLocationToBackend(double lat, double lng) async {
    try {
      await ApiClient.instance.dio.post('/users/location', data: {
        'latitude': lat,
        'longitude': lng,
      });
      if (kDebugMode) {
        print('User GPS location synced to backend profile.');
      }
    } catch (e) {
      _lastError = 'Location captured but could not be synced. It will retry next time.';
      if (kDebugMode) print('GPS sync failed: $e');
    }
  }
}
