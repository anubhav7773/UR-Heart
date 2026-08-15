import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/security_service.dart';

class AppAuthProvider extends ChangeNotifier {
  static final AppAuthProvider instance = AppAuthProvider._internal();
  factory AppAuthProvider() => instance;
  AppAuthProvider._internal();

  bool _isAuthenticated = false;
  String? _userId;
  bool _isProfileComplete = false;
  bool _isPremium = false;
  bool _isAdmin = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  bool get isProfileComplete => _isProfileComplete;
  bool get isPremium => _isPremium;
  bool get isAdmin => _isAdmin;

  Future<void> loadSession() async {
    final token = await StorageManager.instance.getAuthToken();
    _userId = await StorageManager.instance.getUserId();
    _isProfileComplete = await StorageManager.instance.isProfileComplete();
    _isPremium = await StorageManager.instance.isPremium();
    _isAdmin = await StorageManager.instance.isAdmin();
    _isAuthenticated = token != null && token.isNotEmpty;
    
    // Apply dynamic role-based screenshot & recording policy
    await WindowSecurityService.applySecurityPolicy(isAdmin: _isAdmin);

    if (_isAuthenticated) {
      // Sync FCM token and location for active session
      FcmService.instance.syncFcmToken();
      LocationService.instance.updateUserLocation();
    }
    notifyListeners();
  }

  Future<void> handleLoginSuccess({
    required String token,
    required String userId,
    required bool isProfileComplete,
    required bool isPremium,
    bool isAdmin = false,
  }) async {
    // 1. Purge previous SharedPreferences and SecureStorage session state completely
    await purgeSession();

    // 2. Save new dynamic credentials
    await StorageManager.instance.saveAuthToken(token);
    await StorageManager.instance.saveUserId(userId);
    await StorageManager.instance.setProfileComplete(isProfileComplete);
    await StorageManager.instance.setPremiumStatus(isPremium);
    await StorageManager.instance.setAdminStatus(isAdmin);

    _userId = userId;
    _isProfileComplete = isProfileComplete;
    _isPremium = isPremium;
    _isAdmin = isAdmin;
    _isAuthenticated = true;

    // 3. Immediately apply screenshot / screen recording security policy
    await WindowSecurityService.applySecurityPolicy(isAdmin: isAdmin);

    notifyListeners();

    // 4. Immediately sync FCM Device Token & GPS location with valid Auth Bearer Header
    FcmService.instance.syncFcmToken();
    LocationService.instance.updateUserLocation();
  }

  Future<void> purgeSession() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.clear();
    } catch (_) {}

    await StorageManager.instance.clearAll();

    _isAuthenticated = false;
    _userId = null;
    _isProfileComplete = false;
    _isPremium = false;
    _isAdmin = false;

    // Re-lock window with FLAG_SECURE on session termination
    await WindowSecurityService.applySecurityPolicy(isAdmin: false);

    notifyListeners();
  }

  Future<void> logout() async {
    await purgeSession();
  }
}
