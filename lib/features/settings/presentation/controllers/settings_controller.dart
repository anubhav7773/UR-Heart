import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/storage/secure_session_storage.dart';
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

  SettingsController(this._repo)
      : super(SettingsState(settings: _repo.getSettings())) {
    _loadUserRoleAndEmail();
  }

  Future<void> _loadUserRoleAndEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('ur_heart_user_email') ??
          prefs.getString('profile_email') ??
          prefs.getString('email') ??
          '';
      final isSuper = savedEmail.trim().toLowerCase() == 'kshtriyaanubhav9120@gmail.com';
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
    final isSuper = clean == 'kshtriyaanubhav9120@gmail.com';
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
      state = state.copyWith(
        isIncinerating: false,
        successMessage: 'Account & data irrevocably purged.',
      );
      return success;
    } catch (_) {
      state = state.copyWith(
        isIncinerating: false,
        errorMessage: 'Account incinerator failed.',
      );
      return false;
    }
  }

  Future<void> toggleGhostCloak(bool value) => toggleIncognito(value);
  Future<void> toggleMasterPush(bool value) => toggleMasterResonance(value);
  Future<void> rotateEncryptionKeys([dynamic context]) => rotateKey();
  Future<bool> executePermanentAccountErasure([dynamic context]) => incinerateAccount();
  Future<void> logout([dynamic context]) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await SecureSessionStorage.instance.clearAllSessionData();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ur_heart_profile_setup_completed');
      await prefs.remove('ur_heart_has_entered_sanctuary');
      await prefs.remove('ur_heart_auth_token');
      await prefs.remove('auth_token');
      await prefs.remove('ur_heart_user_email');
      await prefs.remove('ur_heart_user_name');
      await prefs.remove('ur_heart_user_id');
      await prefs.remove('profile_full_name');
      await prefs.remove('profile_dob');
      await prefs.remove('ur_heart_selected_dob');
      await prefs.remove('profile_age');
      await prefs.remove('ur_heart_user_age');
      await prefs.remove('profile_gender');
      await prefs.remove('profile_location');
      await prefs.remove('profile_bio');
      await prefs.remove('profile_profession');
      await prefs.remove('profile_education');
      await prefs.remove('profile_contact_bridge_platform');
      await prefs.remove('profile_contact_bridge_handle');
      for (int i = 1; i <= 5; i++) {
        await prefs.remove('profile_photo_slot_$i');
      }
    } catch (_) {}
    state = state.copyWith(successMessage: 'Logged out of Sanctuary');
  }

  void clearBanner() {
    state = state.copyWith(successMessage: null, errorMessage: null);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsController(repo);
});
