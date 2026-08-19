import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyFcmToken = 'auth_fcm_token';

  static Future<void> saveAuthCredentials({
    required String token,
    required String userId,
  }) async {
    await _storage.write(key: _keyAccessToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  static Future<void> saveFcmToken(String fcmToken) async {
    await _storage.write(key: _keyFcmToken, value: fcmToken);
  }

  static Future<String?> getFcmToken() async {
    return await _storage.read(key: _keyFcmToken);
  }

  static Future<void> clearAuth() async {
    await _storage.deleteAll();
  }
}
