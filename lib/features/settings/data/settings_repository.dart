import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/installation_service.dart';
import '../domain/settings_models.dart';

/// Repository managing user preferences, key rotation, and DPDP Sec 12 account incinerator
class SettingsRepository {
  final ApiClient? _apiClient;

  SanctuarySettings _settings = const SanctuarySettings(
    masterResonance: true,
    discreetMode: false,
    nightSanctuarySlumber: true,
    isIncognito: false,
    activeKeyFingerprint: 'CURVE25519-7F3A-89BE-4402',
    userEmail: 'aanya.sharma@sanctuary.in',
  );

  SettingsRepository([this._apiClient]);

  SanctuarySettings getSettings() => _settings;

  void setUserEmail(String email) {
    _settings = _settings.copyWith(userEmail: email);
  }

  Future<SanctuarySettings> updateSettings({
    bool? masterResonance,
    bool? discreetMode,
    bool? nightSanctuarySlumber,
    bool? isIncognito,
  }) async {
    _settings = _settings.copyWith(
      masterResonance: masterResonance,
      discreetMode: discreetMode,
      nightSanctuarySlumber: nightSanctuarySlumber,
      isIncognito: isIncognito,
    );

    try {
      await _apiClient?.dio.put<dynamic>(
        ApiEndpoints.userPreferences,
        data: {
          'master_resonance': _settings.masterResonance,
          'discreet_mode': _settings.discreetMode,
          'night_slumber': _settings.nightSanctuarySlumber,
          'is_incognito': _settings.isIncognito,
        },
      );
    } catch (_) {}

    return _settings;
  }

  Future<String> rotateEncryptionKey() async {
    const hexChars = '0123456789ABCDEF';
    final random = Random();
    final buffer = StringBuffer('CURVE25519-');
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 4; j++) {
        buffer.write(hexChars[random.nextInt(16)]);
      }
      if (i < 2) buffer.write('-');
    }

    final newFingerprint = buffer.toString();
    _settings = _settings.copyWith(activeKeyFingerprint: newFingerprint);

    try {
      await _apiClient?.dio.post<dynamic>(
        ApiEndpoints.rotateEncryptionKey,
        data: {'key_fingerprint': newFingerprint},
      );
    } catch (_) {}

    return newFingerprint;
  }

  Future<bool> incinerateAccountIrrevocably() async {
    try {
      await _apiClient?.dio.delete<dynamic>(
        ApiEndpoints.incinerateAccount,
      );
    } catch (_) {}

    // 1. Purge local Installation UUID (Zero-on-Delete Sandbox Reset)
    await InstallationService.resetInstallationUuid();
    InstallationService.clearMemoryCache();

    // 2. Clear in-memory settings
    _settings = const SanctuarySettings();

    return true;
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SettingsRepository(client);
});
