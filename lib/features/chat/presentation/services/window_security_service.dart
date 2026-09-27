import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Secure window management service enforcing screenshot & screen-recording prevention
/// for 1:1 Encrypted Dialogues (Screen 9) per DPDP Act 2023 directives.
class WindowSecurityService {
  const WindowSecurityService._();

  /// Enables FLAG_SECURE on Android devices to block screen capture and recording.
  /// Safely handles tests and desktop/iOS runtimes without crashing.
  static Future<bool> enableSecureMode() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        return true;
      }
    } catch (e) {
      debugPrint('WindowSecurityService: enableSecureMode suppressed: $e');
    }
    return false;
  }

  /// Clears FLAG_SECURE when user exits Screen 9 dialogue viewport.
  static Future<bool> disableSecureMode() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        return true;
      }
    } catch (e) {
      debugPrint('WindowSecurityService: disableSecureMode suppressed: $e');
    }
    return false;
  }
}
