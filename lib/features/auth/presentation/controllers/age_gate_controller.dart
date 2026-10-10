import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/services/installation_service.dart';

class AgeGateState {
  final DateTime? birthDate;
  final int calculatedAge;
  final bool isAdult;
  final bool isUnderage;
  final bool isQuarantined;
  final String statusBadgeText;
  final DateTime? quarantineUntil;

  const AgeGateState({
    this.birthDate,
    this.calculatedAge = 0,
    this.isAdult = false,
    this.isUnderage = false,
    this.isQuarantined = false,
    this.statusBadgeText = '',
    this.quarantineUntil,
  });

  AgeGateState copyWith({
    DateTime? birthDate,
    int? calculatedAge,
    bool? isAdult,
    bool? isUnderage,
    bool? isQuarantined,
    String? statusBadgeText,
    DateTime? quarantineUntil,
  }) {
    return AgeGateState(
      birthDate: birthDate ?? this.birthDate,
      calculatedAge: calculatedAge ?? this.calculatedAge,
      isAdult: isAdult ?? this.isAdult,
      isUnderage: isUnderage ?? this.isUnderage,
      isQuarantined: isQuarantined ?? this.isQuarantined,
      statusBadgeText: statusBadgeText ?? this.statusBadgeText,
      quarantineUntil: quarantineUntil ?? this.quarantineUntil,
    );
  }
}

class AgeGateController extends StateNotifier<AgeGateState> {
  static const String quarantineKey = 'ur_heart_quarantine_until';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  AgeGateController() : super(const AgeGateState()) {
    checkQuarantine();
  }

  Future<void> checkQuarantine() async {
    int? millis;
    try {
      final secVal = await _secureStorage.read(key: quarantineKey);
      if (secVal != null && secVal.isNotEmpty) {
        millis = int.tryParse(secVal);
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final prefMillis = prefs.getInt(quarantineKey);
    millis ??= prefMillis;

    if (millis != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(millis);
      if (DateTime.now().isBefore(expiry)) {
        // Enforce bidirectional synchronization so clearing one storage cannot bypass quarantine
        await prefs.setInt(quarantineKey, millis);
        try {
          await _secureStorage.write(key: quarantineKey, value: millis.toString());
        } catch (_) {}

        state = state.copyWith(
          isQuarantined: true,
          quarantineUntil: expiry,
          statusBadgeText: 'Device Quarantined (Minor Safety Policy)',
        );
      } else {
        await prefs.remove(quarantineKey);
        try {
          await _secureStorage.delete(key: quarantineKey);
        } catch (_) {}
      }
    }
  }

  Future<void> evaluateDob(DateTime dob) async {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }

    if (age < 18) {
      // 180-Day Hardware Quarantine (FE-VULN-13)
      final quarantineUntil = now.add(const Duration(days: 180));
      final quarantineExpiryMs = quarantineUntil.millisecondsSinceEpoch;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(quarantineKey, quarantineExpiryMs);
      try {
        await _secureStorage.write(key: quarantineKey, value: quarantineExpiryMs.toString());
      } catch (_) {}

      // Register device hardware fingerprint in backend quarantine registry
      try {
        final installationId = await InstallationService.getInstallationUuid();
        final dio = Dio(BaseOptions(
          baseUrl: ApiEndpoints.defaultBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        await dio.post<dynamic>(
          '/api/v1/auth/quarantine-device',
          data: {
            'device_fingerprint': installationId,
            'reason': 'underage_attempt_age_gate',
          },
        );
      } catch (e) {
        debugPrint('[QUARANTINE] Backend registration error: $e');
      }

      state = state.copyWith(
        birthDate: dob,
        calculatedAge: age,
        isAdult: false,
        isUnderage: true,
        isQuarantined: true,
        quarantineUntil: quarantineUntil,
        statusBadgeText: 'Underage Restricted (Strictly 18+)',
      );
    } else {
      state = state.copyWith(
        birthDate: dob,
        calculatedAge: age,
        isAdult: true,
        isUnderage: false,
        statusBadgeText: 'Verified Adult ($age y/o)',
      );
    }
  }

  Future<void> clearQuarantine() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(quarantineKey);
    try {
      await _secureStorage.delete(key: quarantineKey);
    } catch (_) {}
    state = state.copyWith(isQuarantined: false, quarantineUntil: null);
  }
}

final ageGateControllerProvider =
    StateNotifierProvider<AgeGateController, AgeGateState>((ref) {
  return AgeGateController();
});
