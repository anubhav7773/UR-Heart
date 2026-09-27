import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class InstallationService {
  static const String _uuidKey = 'urheart_installation_uuid_v4';
  static const String legacyUuidKey = 'ur_heart_installation_uuid';
  static final InstallationService instance = InstallationService._internal();

  InstallationService._internal();

  static String? _cachedUuid;

  Future<String> getOrCreateInstallationUuid() async {
    return getInstallationUuid();
  }

  Future<void> clearInstallationData() async {
    await resetInstallationUuid();
  }

  static Future<String> getInstallationUuid() async {
    final cached = _cachedUuid;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final prefs = await SharedPreferences.getInstance();
    String? existingUuid = prefs.getString(_uuidKey) ?? prefs.getString(legacyUuidKey);

    if (existingUuid == null || existingUuid.isEmpty) {
      existingUuid = const Uuid().v4();
      await prefs.setString(_uuidKey, existingUuid);
      await prefs.setString(legacyUuidKey, existingUuid);
    }

    _cachedUuid = existingUuid;
    return existingUuid;
  }

  static void clearMemoryCache() {
    _cachedUuid = null;
  }

  static Future<void> resetInstallationUuid() async {
    _cachedUuid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uuidKey);
    await prefs.remove(legacyUuidKey);
  }
}
