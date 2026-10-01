import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hardware-Backed Secure Session Storage (SEC-HIGH-05)
///
/// Encapsulates all authentication JWTs, user identities, and sensitive credentials.
/// Configured with Android Keystore backed EncryptedSharedPreferences to prevent
/// plaintext ADB extraction and memory inspection attacks.
class SecureSessionStorage {
  static final SecureSessionStorage instance = SecureSessionStorage._internal();
  SecureSessionStorage._internal();

  // Hardware-backed Android Keystore EncryptedSharedPreferences options
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  // Key Constants
  static const String keyAuthToken = 'ur_heart_auth_token';
  static const String keyLegacyAuthToken = 'auth_token';
  static const String keyUserEmail = 'ur_heart_user_email';
  static const String keyLegacyProfileEmail = 'profile_email';
  static const String keyUserId = 'ur_heart_user_id';
  static const String keyUserName = 'ur_heart_user_name';
  static const String keyUserPhoto = 'ur_heart_user_photo';
  static const String keyUserRole = 'user_role';
  static const String keyProfileCompleted = 'ur_heart_profile_setup_completed';

  /// Saves the primary authentication token in hardware-backed secure storage.
  Future<void> saveAuthToken(String token) async {
    try {
      await _secureStorage.write(key: keyAuthToken, value: token);
      await _secureStorage.write(key: keyLegacyAuthToken, value: token);
      
      // Wipe any lingering plaintext copy in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyAuthToken);
      await prefs.remove(keyLegacyAuthToken);
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error saving auth token: $e');
    }
  }

  /// Retrieves the authentication token with transparent legacy migration.
  Future<String?> getAuthToken() async {
    try {
      String? token = await _secureStorage.read(key: keyAuthToken);
      if (token != null && token.isNotEmpty) return token;

      token = await _secureStorage.read(key: keyLegacyAuthToken);
      if (token != null && token.isNotEmpty) return token;

      // Transparent Migration Check from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(keyAuthToken) ?? prefs.getString(keyLegacyAuthToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        // Upgrade to hardware secure storage immediately
        await _secureStorage.write(key: keyAuthToken, value: legacyToken);
        await prefs.remove(keyAuthToken);
        await prefs.remove(keyLegacyAuthToken);
        debugPrint('[SecureSessionStorage] Upgraded plaintext auth token to hardware-backed Keystore.');
        return legacyToken;
      }
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error reading auth token: $e');
    }
    return null;
  }

  /// Saves user profile credentials securely.
  Future<void> saveUserSession({
    required String? userId,
    required String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    bool? isProfileCompleted,
  }) async {
    try {
      if (userId != null) await _secureStorage.write(key: keyUserId, value: userId);
      if (email != null) {
        await _secureStorage.write(key: keyUserEmail, value: email);
        await _secureStorage.write(key: keyLegacyProfileEmail, value: email);
      }
      if (displayName != null) await _secureStorage.write(key: keyUserName, value: displayName);
      if (photoUrl != null) await _secureStorage.write(key: keyUserPhoto, value: photoUrl);
      if (role != null) await _secureStorage.write(key: keyUserRole, value: role);
      if (isProfileCompleted != null) {
        await _secureStorage.write(key: keyProfileCompleted, value: isProfileCompleted.toString());
      }

      // Cleanse plaintext SharedPreferences of PII
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyUserId);
      await prefs.remove(keyUserEmail);
      await prefs.remove(keyLegacyProfileEmail);
      await prefs.remove(keyUserName);
      await prefs.remove(keyUserPhoto);
      await prefs.remove(keyUserRole);
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error persisting user session: $e');
    }
  }

  /// Retrieves user email with legacy fallback.
  Future<String?> getUserEmail() async {
    try {
      final email = await _secureStorage.read(key: keyUserEmail);
      if (email != null && email.isNotEmpty) return email;

      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(keyUserEmail) ?? prefs.getString(keyLegacyProfileEmail);
      if (legacy != null && legacy.isNotEmpty) {
        await _secureStorage.write(key: keyUserEmail, value: legacy);
        await prefs.remove(keyUserEmail);
        await prefs.remove(keyLegacyProfileEmail);
        return legacy;
      }
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error reading user email: $e');
    }
    return null;
  }

  /// Retrieves user ID with legacy fallback.
  Future<String?> getUserId() async {
    try {
      final uid = await _secureStorage.read(key: keyUserId);
      if (uid != null && uid.isNotEmpty) return uid;

      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(keyUserId);
      if (legacy != null && legacy.isNotEmpty) {
        await _secureStorage.write(key: keyUserId, value: legacy);
        await prefs.remove(keyUserId);
        return legacy;
      }
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error reading user ID: $e');
    }
    return null;
  }

  /// Retrieves user role.
  Future<String?> getUserRole() async {
    try {
      final role = await _secureStorage.read(key: keyUserRole);
      if (role != null && role.isNotEmpty) return role;

      final prefs = await SharedPreferences.getInstance();
      final legacyRole = prefs.getString(keyUserRole);
      if (legacyRole != null && legacyRole.isNotEmpty) {
        await _secureStorage.write(key: keyUserRole, value: legacyRole);
        await prefs.remove(keyUserRole);
        return legacyRole;
      }
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error reading user role: $e');
    }
    return null;
  }

  /// Checks if profile setup is marked completed.
  Future<bool> isProfileSetupCompleted() async {
    try {
      final val = await _secureStorage.read(key: keyProfileCompleted);
      if (val != null) return val.toLowerCase() == 'true';

      final prefs = await SharedPreferences.getInstance();
      final legacyVal = prefs.getBool(keyProfileCompleted);
      if (legacyVal != null) {
        await _secureStorage.write(key: keyProfileCompleted, value: legacyVal.toString());
        return legacyVal;
      }
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error reading profile setup status: $e');
    }
    return false;
  }

  /// Atomic Session Flushing Pipeline.
  /// Irrevocably purges all hardware keystore items and residual SharedPreferences tokens.
  Future<void> clearAllSessionData() async {
    try {
      // 1. Purge all hardware-backed secure storage keys
      await _secureStorage.deleteAll();

      // 2. Clear any lingering auth tokens in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyAuthToken);
      await prefs.remove(keyLegacyAuthToken);
      await prefs.remove(keyUserId);
      await prefs.remove(keyUserEmail);
      await prefs.remove(keyLegacyProfileEmail);
      await prefs.remove(keyUserName);
      await prefs.remove(keyUserPhoto);
      await prefs.remove(keyUserRole);
      await prefs.remove(keyProfileCompleted);
      debugPrint('[SecureSessionStorage] Atomic session flush completed successfully.');
    } catch (e) {
      debugPrint('[SecureSessionStorage] Error during atomic session flush: $e');
    }
  }
}
