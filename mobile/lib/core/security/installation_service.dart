import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Sandbox Ephemeral Installation Identity Service
/// Enforces the "Zero on Delete" architecture per URH-PRD-001 (FR-01) & URH-SYS-008.
/// Stores the ephemeral installation UUID in Android's private app sandbox.
/// Clearing app data or uninstalling the app wipes this storage, triggering
/// an atomic streak and reward balance reset to 0 upon next session sync.
class InstallationService {
  static const String _keyInstallationUuid = 'urheart_ephemeral_install_uuid';

  /// Retrieves the existing Installation UUID or generates and persists a fresh UUID v4.
  static Future<String> getOrCreateInstallationUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUuid = prefs.getString(_keyInstallationUuid);

    if (currentUuid == null || currentUuid.isEmpty) {
      currentUuid = const Uuid().v4();
      await prefs.setString(_keyInstallationUuid, currentUuid);
    }
    return currentUuid;
  }
}
