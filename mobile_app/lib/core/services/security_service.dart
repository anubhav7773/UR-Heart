import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../security/flutter_windowmanager.dart';
import '../security/storage_manager.dart';

/// Role-based Window Security Manager
/// Controls Android FLAG_SECURE dynamically:
/// - Admin / Creator account: Clears FLAG_SECURE to enable clear screenshots & screen recordings for app demos.
/// - Standard users: Adds FLAG_SECURE to strictly block screenshots and screen recordings (renders black screen).
class WindowSecurityService {
  static Future<void> applySecurityPolicy({required bool isAdmin}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (isAdmin) {
        // Admin bypass: Screen recording & screenshots allowed for demo videos
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        if (kDebugMode) {
          print('[WindowSecurityService] FLAG_SECURE CLEARED (Admin Mode Active)');
        }
      } else {
        // All other users: Strictly block screenshots and screen recordings
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        if (kDebugMode) {
          print('[WindowSecurityService] FLAG_SECURE APPLIED (Protected User Mode)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WindowSecurityService] Error applying security policy: $e');
      }
    }
  }

  /// Reads cached role from Secure Storage and applies security flags accordingly.
  static Future<void> syncFromStorage() async {
    try {
      final bool isAdmin = await StorageManager.instance.isAdmin();
      await applySecurityPolicy(isAdmin: isAdmin);
    } catch (e) {
      if (kDebugMode) {
        print('[WindowSecurityService] syncFromStorage error: $e');
      }
      await applySecurityPolicy(isAdmin: false);
    }
  }
}
