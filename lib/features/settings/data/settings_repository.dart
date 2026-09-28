import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/installation_service.dart';
import '../domain/settings_models.dart';

export '../domain/settings_models.dart';

/// Repository managing user preferences, key rotation, and DPDP Sec 12 account incinerator
class SettingsRepository {
  final Dio _dio;

  SanctuarySettings _settings = const SanctuarySettings(
    masterResonance: true,
    discreetMode: false,
    nightSanctuarySlumber: true,
    isIncognito: false,
    activeKeyFingerprint: 'CURVE25519-7F3A-89BE-4402',
    userEmail: '',
  );

  SettingsRepository([Dio? dio]) : _dio = dio ?? Dio();

  SanctuarySettings getSettings() => _settings;

  void setUserEmail(String email) {
    _settings = _settings.copyWith(userEmail: email);
  }

  /// Persists incognito, discreet mode & alerts directly to database
  Future<bool> updatePreferences(UserPreferences preferences) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/v1/user/preferences',
        data: preferences.toJson(),
      );
      if (response.statusCode == 200) {
        _settings = _settings.copyWith(
          isIncognito: preferences.isIncognito ?? _settings.isIncognito,
          discreetMode: preferences.discreetMode ?? _settings.discreetMode,
        );
        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Persists slumber mode to backend database via PATCH /api/v1/profile/slumber-mode (ACT-06)
  Future<bool> updateSlumberMode(bool isActive) async {
    _settings = _settings.copyWith(nightSanctuarySlumber: isActive);
    try {
      final response = await _dio.patch<dynamic>(
        '/api/v1/profile/slumber-mode',
        data: {'is_slumber_active': isActive},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Persists incognito and discreet mode via PUT /api/v1/user/preferences (ACT-15 & ACT-16)
  Future<bool> updateUserPreferences({bool? isIncognito, bool? isDiscreet}) async {
    _settings = _settings.copyWith(
      isIncognito: isIncognito ?? _settings.isIncognito,
      discreetMode: isDiscreet ?? _settings.discreetMode,
    );
    try {
      final response = await _dio.put<dynamic>(
        '/api/v1/user/preferences',
        data: {
          if (isIncognito != null) 'is_incognito': isIncognito,
          if (isDiscreet != null) 'discreet_mode': isDiscreet,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Backward-compatible updateSettings
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
      await _dio.put<dynamic>(
        '/api/v1/user/preferences',
        data: {
          'discreet_mode': _settings.discreetMode,
          'is_incognito': _settings.isIncognito,
          'push_notifications_enabled': _settings.masterResonance,
        },
      );
      return _settings;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Registers genuine X25519 public key in backend vault
  Future<bool> registerRotatedPublicKey(String publicKeyBase64) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/crypto/rotate-key',
        data: {'public_key_base64': publicKeyBase64},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final fp = data['key_fingerprint'] as String? ?? 'ROTATED';
        _settings = _settings.copyWith(activeKeyFingerprint: fp);
        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Backward-compatible rotateEncryptionKey generator
  Future<String> rotateEncryptionKey() async {
    // Generate valid 32-byte Base64 key
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final base64Key = base64UrlEncode(bytes);

    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/crypto/rotate-key',
        data: {'public_key_base64': base64Key},
      );
      final data = response.data as Map<String, dynamic>;
      final fp = data['key_fingerprint'] as String? ?? base64Key.substring(0, 8);
      _settings = _settings.copyWith(activeKeyFingerprint: fp);
      return fp;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// DPDP Sec 12: Transmits mandatory confirmation payload 'ERASE'.
  Future<bool> incinerateAccountIrrevocably() async {
    try {
      final response = await _dio.delete<dynamic>(
        '/api/v1/auth/incinerate-account',
        data: {
          'confirmation_token': 'ERASE',
          'reason': 'user_authorized_dpdp_erasure'
        },
      );

      // 1. Purge local Installation UUID (Zero-on-Delete Sandbox Reset)
      await InstallationService.resetInstallationUuid();
      InstallationService.clearMemoryCache();

      // 2. Clear in-memory settings
      _settings = const SanctuarySettings();

      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    throw ServerException(e.response?.data?['detail'] as String? ?? 'Settings update rejected.');
  }
}

String base64UrlEncode(List<int> bytes) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final buffer = StringBuffer();
  for (int i = 0; i < bytes.length; i += 3) {
    final b0 = bytes[i];
    final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;

    buffer.write(chars[(b0 >> 2) & 0x3F]);
    buffer.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
    if (i + 1 < bytes.length) {
      buffer.write(chars[((b1 << 2) | (b2 >> 6)) & 0x3F]);
    } else {
      buffer.write('=');
    }
    if (i + 2 < bytes.length) {
      buffer.write(chars[b2 & 0x3F]);
    } else {
      buffer.write('=');
    }
  }
  return buffer.toString();
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SettingsRepository(dioClient.dio);
});
