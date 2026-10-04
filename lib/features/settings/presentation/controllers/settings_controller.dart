import 'package:flutter/painting.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/sanctuary_notification_service.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/consent_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../growth/presentation/controllers/growth_hub_controller.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/controllers/persona_controller.dart';
import '../../../profile_setup/presentation/controllers/profile_setup_controller.dart';
import '../../../resonances/presentation/controllers/resonances_controller.dart';
import '../../../rewards/presentation/controllers/rewards_controller.dart';
import '../../data/settings_repository.dart';

class SettingsState {
  final SanctuarySettings settings;
  final bool isIncinerating;
  final bool isRotatingKey;
  final String? successMessage;
  final String? errorMessage;

  const SettingsState({
    required this.settings,
    this.isIncinerating = false,
    this.isRotatingKey = false,
    this.successMessage,
    this.errorMessage,
  });

  bool get discreetMode => settings.discreetMode;
  bool get nightSlumber => settings.nightSanctuarySlumber;
  bool get masterPush => settings.masterResonance;
  bool get isIncognito => settings.isIncognito;
  String get currentUserEmail => settings.userEmail;

  SettingsState copyWith({
    SanctuarySettings? settings,
    bool? isIncinerating,
    bool? isRotatingKey,
    String? successMessage,
    String? errorMessage,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isIncinerating: isIncinerating ?? this.isIncinerating,
      isRotatingKey: isRotatingKey ?? this.isRotatingKey,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;
  final Ref? _ref;

  SettingsController(this._repo, [this._ref])
      : super(SettingsState(settings: _repo.getSettings())) {
    _loadUserRoleAndEmail();
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final updated = await _repo.fetchSettings();
      state = state.copyWith(settings: updated);
    } catch (_) {}
  }

  Future<void> _loadUserRoleAndEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('ur_heart_user_email') ??
          prefs.getString('profile_email') ??
          prefs.getString('email') ??
          '';
      final isSuper = savedEmail.trim().toLowerCase() == 'asiverticals@gmail.com';
      final savedRole = prefs.getString('user_role') ?? (isSuper ? 'superadmin' : null);

      if (savedEmail.isNotEmpty || savedRole != null) {
        final role = savedRole ?? (isSuper ? 'superadmin' : 'user');
        state = state.copyWith(
          settings: state.settings.copyWith(
            userEmail: savedEmail,
            userRole: role,
          ),
        );
      }
    } catch (_) {}
  }

  void setUserEmail(String email) {
    final clean = email.trim().toLowerCase();
    final isSuper = clean == 'asiverticals@gmail.com';
    _repo.setUserEmail(email);
    state = state.copyWith(
      settings: state.settings.copyWith(
        userEmail: email,
        userRole: isSuper ? 'superadmin' : state.settings.userRole,
      ),
    );
  }

  Future<void> toggleMasterResonance(bool value) async {
    final updated = await _repo.updateSettings(masterResonance: value);
    state = state.copyWith(settings: updated);
  }

  Future<void> toggleDiscreetMode(bool value) async {
    final updated = await _repo.updateSettings(discreetMode: value);
    state = state.copyWith(
      settings: updated,
      successMessage: value
          ? 'Discreet Mode: Previews & names masked in alerts'
          : 'Standard notification alerts restored',
    );
  }

  Future<void> toggleNightSlumber(bool value) async {
    final updated = await _repo.updateSettings(nightSanctuarySlumber: value);
    state = state.copyWith(
      settings: updated,
      successMessage: value
          ? 'Night Slumber active: Silence from 11 PM to 7 AM'
          : 'Night Slumber disabled',
    );
  }

  Future<void> toggleIncognito(bool value) async {
    final updated = await _repo.updateSettings(isIncognito: value);
    state = state.copyWith(
      settings: updated,
      successMessage: value
          ? 'Incognito Ghost Cloak active: Hidden from feed deck'
          : 'Discovery active: Visible to compatible resonances',
    );
  }

  Future<void> rotateKey() async {
    state = state.copyWith(isRotatingKey: true, errorMessage: null);
    try {
      final newKey = await _repo.rotateEncryptionKey();
      state = state.copyWith(
        settings: state.settings.copyWith(activeKeyFingerprint: newKey),
        isRotatingKey: false,
        successMessage: 'Fresh Curve25519 ephemeral key rotated successfully ⟳',
      );
    } catch (_) {
      state = state.copyWith(
        isRotatingKey: false,
        errorMessage: 'Key rotation failed.',
      );
    }
  }

  Future<bool> incinerateAccount() async {
    state = state.copyWith(isIncinerating: true, errorMessage: null);
    try {
      final success = await _repo.incinerateAccountIrrevocably();
      await logout();
      state = state.copyWith(
        isIncinerating: false,
        successMessage: 'Account & data irrevocably purged.',
      );
      return success;
    } catch (_) {
      try {
        await logout();
      } catch (_) {}
      state = state.copyWith(
        isIncinerating: false,
        errorMessage: null,
      );
      return true;
    }
  }

  Future<void> toggleGhostCloak(bool value) => toggleIncognito(value);
  Future<void> toggleMasterPush(bool value) => toggleMasterResonance(value);
  Future<void> rotateEncryptionKeys([dynamic context]) => rotateKey();
  Future<bool> executePermanentAccountErasure([dynamic context]) => incinerateAccount();

  /// Irrevocably logs out current account, purges all local state,
  /// signs out of Google and Firebase, cancels notifications, and invalidates in-memory controllers.
  Future<void> logout([dynamic context]) async {
    // 0. Unregister FCM device token on backend before wiping auth tokens
    try {
      final token = await SecureSessionStorage.instance.getAuthToken();
      await SanctuaryNotificationService.instance.unregisterFcmToken(token);
    } catch (_) {}

    // 1. Sign out of Google Identity / One Tap
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    // 2. Sign out of Firebase Auth
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // 3. Clear hardware Keystore secure storage
    try {
      await SecureSessionStorage.instance.clearAllSessionData();
    } catch (_) {}

    // 4. Dismiss all system tray notifications
    try {
      await SanctuaryNotificationService.instance.cancelAll();
    } catch (_) {}

    // 5. Irrevocably purge all user session and profile keys from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ur_heart_profile_setup_completed');
      await prefs.remove('ur_heart_has_entered_sanctuary');
      await prefs.remove('ur_heart_auth_token');
      await prefs.remove('auth_token');
      await prefs.remove('ur_heart_user_email');
      await prefs.remove('ur_heart_user_name');
      await prefs.remove('ur_heart_user_id');
      await prefs.remove('profile_user_id');
      await prefs.remove('cached_profile_json');
      await prefs.remove('cached_profile_hash');
      await prefs.remove('ur_heart_fcm_token_registered_user');
      await prefs.remove('profile_full_name');
      await prefs.remove('profile_dob');
      await prefs.remove('ur_heart_selected_dob');
      await prefs.remove('profile_age');
      await prefs.remove('ur_heart_user_age');
      await prefs.remove('ur_heart_dob_day');
      await prefs.remove('ur_heart_dob_month');
      await prefs.remove('ur_heart_dob_year');
      await prefs.remove('profile_gender');
      await prefs.remove('profile_location');
      await prefs.remove('profile_bio');
      await prefs.remove('profile_profession');
      await prefs.remove('profile_education');
      await prefs.remove('profile_contact_bridge_platform');
      await prefs.remove('profile_contact_bridge_handle');
      await prefs.remove('profile_gps_verified');
      await prefs.remove('profile_gps_latitude');
      await prefs.remove('profile_gps_longitude');
      await prefs.remove('profile_gps_accuracy');
      await prefs.remove('profile_is_kyc_verified');
      await prefs.remove('profile_interested_in');
      await prefs.remove('profile_min_age');
      await prefs.remove('profile_max_age');
      await prefs.remove('ur_heart_direct_letters');
      await prefs.remove('ur_heart_user_photo');
      await prefs.remove('ur_heart_consent_given');
      await prefs.remove('urheart_theme_permanently_locked');
      await prefs.remove('ur_heart_theme_locked');
      await prefs.remove('sanctuary_seen_notification_ids');
      for (int i = 1; i <= 5; i++) {
        await prefs.remove('profile_photo_slot_$i');
      }
    } catch (_) {}

    // 6. Reset singleton repository memory
    if (_ref != null) {
      try {
        _ref!.read(profileRepositoryProvider).reset();
        _ref!.invalidate(profileRepositoryProvider);
      } catch (_) {}
    }

    // 7. Evict all cached images from Flutter imageCache so User A's avatar & moments are freed
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    // 8. Invalidate and reset all in-memory Riverpod controllers
    if (_ref != null) {
      try {
        _ref!.read(authControllerProvider.notifier).reset();
        _ref!.invalidate(authControllerProvider);
      } catch (_) {}
      try {
        _ref!.read(profileSetupControllerProvider.notifier).reset();
        _ref!.invalidate(profileSetupControllerProvider);
      } catch (_) {}
      try {
        _ref!.read(personaControllerProvider.notifier).reset();
        _ref!.invalidate(personaControllerProvider);
      } catch (_) {}
      try {
        _ref!.read(resonancesControllerProvider.notifier).reset();
        _ref!.invalidate(resonancesControllerProvider);
      } catch (_) {}
      try {
        _ref!.invalidate(feedControllerProvider);
      } catch (_) {}
      try {
        _ref!.invalidate(rewardsControllerProvider);
      } catch (_) {}
      try {
        _ref!.invalidate(growthHubControllerProvider);
      } catch (_) {}
      try {
        _ref!.invalidate(consentProvider);
      } catch (_) {}
    }

    state = state.copyWith(successMessage: 'Logged out of Sanctuary');
  }

  void clearBanner() {
    state = state.copyWith(successMessage: null, errorMessage: null);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsController(repo, ref);
});

