import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageManager {
  static final StorageManager instance = StorageManager._internal();
  factory StorageManager() => instance;
  StorageManager._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyIsProfileComplete = 'is_profile_complete';
  static const String keyIsPremium = 'is_premium';
  static const String keySkipCount = 'persistent_skip_count';

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: keyAuthToken);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: keyUserId, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: keyUserId);
  }

  Future<void> setProfileComplete(bool complete) async {
    await _storage.write(key: keyIsProfileComplete, value: complete.toString());
  }

  Future<bool> isProfileComplete() async {
    final val = await _storage.read(key: keyIsProfileComplete);
    return val == 'true';
  }

  Future<void> setPremiumStatus(bool isPremium) async {
    await _storage.write(key: keyIsPremium, value: isPremium.toString());
  }

  Future<bool> isPremium() async {
    final val = await _storage.read(key: keyIsPremium);
    return val == 'true';
  }

  static const String keyIsAdmin = 'is_admin';

  Future<void> setAdminStatus(bool isAdmin) async {
    await _storage.write(key: keyIsAdmin, value: isAdmin.toString());
  }

  Future<bool> isAdmin() async {
    final val = await _storage.read(key: keyIsAdmin);
    return val == 'true';
  }

  Future<void> saveSkipCount(int count) async {
    await _storage.write(key: keySkipCount, value: count.toString());
  }

  Future<int> getSkipCount() async {
    final val = await _storage.read(key: keySkipCount);
    return val != null ? int.tryParse(val) ?? 0 : 0;
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: keyAuthToken);
    await _storage.delete(key: keyUserId);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
