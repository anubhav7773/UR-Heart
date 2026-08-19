import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  /// Opens exact GPS coordinates with place name label, eliminating nationwide pin drift.
  static Future<void> openExactLocation({
    required double latitude,
    required double longitude,
    required String placeName,
  }) async {
    final encodedName = Uri.encodeComponent(placeName);

    // 1. Android Intent: geo URI with coordinate-pinned marker & label
    final Uri androidGeoUri = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude($encodedName)',
    );

    // 2. iOS Intent: Apple Maps coordinate-locked search
    final Uri appleMapsUri = Uri.parse(
      'https://maps.apple.com/?q=$encodedName&ll=$latitude,$longitude',
    );

    // 3. Fallback Universal Web URL (pinned coordinates)
    final Uri webMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      if (Platform.isAndroid) {
        if (await canLaunchUrl(androidGeoUri)) {
          await launchUrl(androidGeoUri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (Platform.isIOS) {
        if (await canLaunchUrl(appleMapsUri)) {
          await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Universal fallback
      if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback directly to universal web maps URL
      try {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }
}
