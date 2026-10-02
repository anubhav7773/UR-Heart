import 'package:flutter/foundation.dart';
import '../../../../core/services/flutter_windowmanager.dart';
import 'web_security_stub.dart'
    if (dart.library.js_interop) 'web_security_web.dart';

/// Secure window management service enforcing screenshot & screen-recording prevention
/// for 1:1 Encrypted Dialogues (Screen 9) per DPDP Act 2023 directives.
class WindowSecurityService {
  const WindowSecurityService._();

  /// Enables FLAG_SECURE on Android and privacy veil / screenshot shields on Web.
  /// Safely handles tests and desktop/iOS runtimes without crashing.
  static Future<bool> enableSecureMode() async {
    if (kIsWeb) {
      setWebPrivacyMode(true);
      return true;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
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
    if (kIsWeb) {
      setWebPrivacyMode(false);
      return true;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        return true;
      }
    } catch (e) {
      debugPrint('WindowSecurityService: disableSecureMode suppressed: $e');
    }
    return false;
  }
}
