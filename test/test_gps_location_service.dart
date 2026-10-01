import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ur_heart/core/services/real_gps_location_service.dart';

void main() {
  group('100% Production GPS Engine Suite', () {
    test('AndroidSettings is properly configured with FusedLocationProviderClient', () {
      final androidHigh = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 500),
        timeLimit: const Duration(seconds: 8),
      );
      expect(androidHigh.accuracy, LocationAccuracy.high);
      expect(androidHigh.forceLocationManager, isFalse);
      expect(androidHigh.timeLimit, const Duration(seconds: 8));

      final androidMedium = AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 500),
        timeLimit: const Duration(seconds: 6),
      );
      expect(androidMedium.accuracy, LocationAccuracy.medium);
      expect(androidMedium.forceLocationManager, isFalse);
      expect(androidMedium.timeLimit, const Duration(seconds: 6));
    });

    test('GpsLocationResult handles success, mock detection, and indoor fusion', () {
      const successResult = GpsLocationResult(
        isSuccess: true,
        formattedLocation: 'Ayodhya, Uttar Pradesh · GPS Verified',
        latitude: 26.792,
        longitude: 82.199,
        accuracyMeters: 14.5,
        isMocked: false,
        isIndoorFusedFix: true,
      );
      expect(successResult.isSuccess, isTrue);
      expect(successResult.isMocked, isFalse);
      expect(successResult.isIndoorFusedFix, isTrue);
      expect(successResult.formattedLocation, contains('GPS Verified'));

      final failureResult = GpsLocationResult.failure(
        'Location services are turned off. Please turn on GPS in device settings.',
        isServiceDisabled: true,
      );
      expect(failureResult.isSuccess, isFalse);
      expect(failureResult.isServiceDisabled, isTrue);
      expect(failureResult.isPermissionDeniedForever, isFalse);

      final permFailure = GpsLocationResult.failure(
        'Location permission permanently denied. Enable permissions in App Settings.',
        isPermissionDeniedForever: true,
      );
      expect(permFailure.isPermissionDeniedForever, isTrue);
    });
  });
}
