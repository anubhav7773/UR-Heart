import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/settings_repository.dart';
import '../../domain/settings_models.dart';

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
      : super(SettingsState(settings: _repo.getSettings()));

  void setUserEmail(String email) {
    _repo.setUserEmail(email);
    state = state.copyWith(
      settings: state.settings.copyWith(userEmail: email),
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
