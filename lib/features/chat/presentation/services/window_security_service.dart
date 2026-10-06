import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/flutter_windowmanager.dart';
import '../../../../core/storage/secure_session_storage.dart';
import 'web_security_stub.dart'
    if (dart.library.js_interop) 'web_security_web.dart';

/// Secure window management service enforcing screenshot & screen-recording prevention
/// for 1:1 Encrypted Dialogues (Screen 9) per DPDP Act 2023 directives.
///
/// Automatically bypasses FLAG_SECURE and web shields for the sovereign founder account
/// (asiverticals@gmail.com / superadmin) to facilitate marketing assets, video demos,
/// and Play Store listing materials across the entire application.
class WindowSecurityService {
  const WindowSecurityService._();

  /// Checks if current authenticated session is authorized to bypass screenshot restrictions.
  static Future<bool> isBypassedUser() async {
    try {
      final email = await SecureSessionStorage.instance.getUserEmail();
      if (email != null && email.trim().toLowerCase() == 'asiverticals@gmail.com') {
        return true;
      }
      final role = await SecureSessionStorage.instance.getUserRole();
      if (role?.trim().toLowerCase() == 'superadmin') {
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final pEmail = prefs.getString('ur_heart_user_email') ??
          prefs.getString('profile_email') ??
          prefs.getString('email');
      if (pEmail != null && pEmail.trim().toLowerCase() == 'asiverticals@gmail.com') {
        return true;
      }
      final pRole = prefs.getString('user_role');
      if (pRole?.trim().toLowerCase() == 'superadmin') {
        return true;
      }
    } catch (e) {
      debugPrint('WindowSecurityService: check bypass error: $e');
    }
    return false;
  }

  /// Enables FLAG_SECURE on Android and privacy veil / screenshot shields on Web.
  /// Safely handles tests and desktop/iOS runtimes without crashing.
  /// If the current user is asiverticals@gmail.com or superadmin, FLAG_SECURE is bypassed
  /// and cleared to ensure screenshots and screen recordings function seamlessly app-wide.
  static Future<bool> enableSecureMode() async {
    if (await isBypassedUser()) {
      await disableSecureMode();
      return true;
    }

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

  /// Clears FLAG_SECURE when user exits Screen 9 dialogue viewport or when superadmin signs in.
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
