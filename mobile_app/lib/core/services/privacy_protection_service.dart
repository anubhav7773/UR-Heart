import 'package:flutter/services.dart';
import '../security/flutter_windowmanager.dart';

class PrivacyProtectionService {
  /// Enables hardware-level screen protection (Screenshots & Screen recording blocked)
  static Future<void> enableSecureScreen() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } on PlatformException catch (_) {
      // Handled silently on unsupported environments / testing
    } catch (_) {
      // Handled silently
    }
  }

  /// Disables screen protection when exiting private views (optional)
  static Future<void> disableSecureScreen() async {
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } on PlatformException catch (_) {
      // Handled silently
    } catch (_) {
      // Handled silently
    }
  }
}
