import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/crypto/sanctuary_crypto_vault.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/installation_service.dart';
import '../../../core/storage/secure_session_storage.dart';
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

  /// Fetches persistent preferences from server and hardware crypto vault
  Future<SanctuarySettings> fetchSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedIncognito = prefs.getBool('pref_is_incognito');
    final cachedFp = prefs.getString('pref_active_key_fp');

    if (cachedIncognito != null || cachedFp != null) {
      _settings = _settings.copyWith(
        isIncognito: cachedIncognito ?? _settings.isIncognito,
        activeKeyFingerprint: cachedFp ?? _settings.activeKeyFingerprint,
      );
    }

    try {
      final res = await _dio.get<dynamic>('/api/v1/user/preferences');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final p = (data['preferences'] as Map<String, dynamic>?) ?? {};
        final serverIncognito = p['is_incognito'] as bool? ?? false;
        var serverFp = p['key_fingerprint'] as String? ?? '';
        final serverKey = p['public_encryption_key'] as String?;

        if (serverKey == null || serverKey.isEmpty || serverFp.contains('INITIALIZING')) {
          // Hardware vault: export or generate genuine key and register
          final localKeyBase64 = await SanctuaryCryptoVault.instance.exportPublicKeyBase64();
          await registerRotatedPublicKey(localKeyBase64);
          if (localKeyBase64.length >= 12) {
            serverFp = 'X25519-${localKeyBase64.substring(0, 6)}...${localKeyBase64.substring(localKeyBase64.length - 4)}';
          }
        }

        _settings = _settings.copyWith(
          isIncognito: serverIncognito,
          activeKeyFingerprint: serverFp.isNotEmpty ? serverFp : _settings.activeKeyFingerprint,
        );

        await prefs.setBool('pref_is_incognito', serverIncognito);
        if (serverFp.isNotEmpty) {
          await prefs.setString('pref_active_key_fp', serverFp);
        }
      }
    } catch (_) {
      try {
        final localKey = await SanctuaryCryptoVault.instance.exportPublicKeyBase64();
        if (localKey.length >= 12) {
          final localFp = 'X25519-${localKey.substring(0, 6)}...${localKey.substring(localKey.length - 4)}';
          _settings = _settings.copyWith(activeKeyFingerprint: localFp);
        }
      } catch (_) {}
    }
    return _settings;
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

    final prefs = await SharedPreferences.getInstance();
    if (isIncognito != null) {
      await prefs.setBool('pref_is_incognito', isIncognito);
    }

    try {
      final res = await _dio.put<dynamic>(
        '/api/v1/user/preferences',
        data: {
          'discreet_mode': _settings.discreetMode,
          'is_incognito': _settings.isIncognito,
          'push_notifications_enabled': _settings.masterResonance,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final fp = data['key_fingerprint'] as String?;
        if (fp != null && fp.isNotEmpty && !fp.contains('INITIALIZING')) {
          _settings = _settings.copyWith(activeKeyFingerprint: fp);
          await prefs.setString('pref_active_key_fp', fp);
        }
      }
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
        final fp = data['key_fingerprint'] as String? ??
            (publicKeyBase64.length >= 12
                ? 'X25519-${publicKeyBase64.substring(0, 6)}...${publicKeyBase64.substring(publicKeyBase64.length - 4)}'
                : 'X25519-ROTATED');
        _settings = _settings.copyWith(activeKeyFingerprint: fp);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pref_active_key_fp', fp);
        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Backward-compatible rotateEncryptionKey generator using real X25519 engine
  Future<String> rotateEncryptionKey() async {
    // Generate genuine X25519 keypair via hardware/secure vault
    final base64Key = await SanctuaryCryptoVault.instance.rotateLocalKeyPair();

    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/crypto/rotate-key',
        data: {'public_key_base64': base64Key},
      );
      final data = response.data as Map<String, dynamic>;
      final fp = data['key_fingerprint'] as String? ??
          (base64Key.length >= 12
              ? 'X25519-${base64Key.substring(0, 6)}...${base64Key.substring(base64Key.length - 4)}'
              : 'X25519-ROTATED');
      _settings = _settings.copyWith(activeKeyFingerprint: fp);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_active_key_fp', fp);
      return fp;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// DPDP Sec 12: Transmits mandatory confirmation payload 'ERASE' and purges local sandbox.
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

      // 2. Clear entire SharedPreferences sandbox
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Purge all secure keystore storage & hardware session data
      await const FlutterSecureStorage().deleteAll();
      await SecureSessionStorage.instance.clearAllSessionData();

      // 4. Clear in-memory settings
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
