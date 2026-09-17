import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class UserLocationResult {
  final double latitude;
  final double longitude;
  final String city;
  final String? locality;

  UserLocationResult({
    required this.latitude,
    required this.longitude,
    required this.city,
    this.locality,
  });
}

class LocationService {
  /// Requests device location, checks GPS service status, and resolves city name
  static Future<UserLocationResult> fetchCurrentLocation() async {
    // 1. Check if location hardware is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    // 2. Check and request runtime permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied by user.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        "Location permissions are permanently denied. Please enable them in device settings.",
      );
    }

    // 3. Fetch GPS fix with balanced accuracy (avoids heavy battery drain)
    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 12),
    );

    // 4. Reverse-geocode coordinates to extract city / district
    String resolvedCity = "Unknown City";
    String? resolvedLocality;

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        // Prioritize locality -> subAdministrativeArea (District) -> administrativeArea
        resolvedCity = place.locality?.isNotEmpty == true
            ? place.locality!
            : (place.subAdministrativeArea?.isNotEmpty == true
                ? place.subAdministrativeArea!
                : (place.administrativeArea ?? "Unknown City"));
        resolvedLocality = place.subLocality;
      }
    } catch (_) {
      // Fallback if reverse-geocoding service is unavailable
      resolvedCity = "Auto-Detected Region";
    }

    return UserLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      city: resolvedCity,
      locality: resolvedLocality,
    );
  }
}
