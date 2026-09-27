import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  AgeGateController() : super(const AgeGateState()) {
    checkQuarantine();
  }

  Future<void> checkQuarantine() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(quarantineKey);
    if (millis != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(millis);
      if (DateTime.now().isBefore(expiry)) {
        state = state.copyWith(
          isQuarantined: true,
          quarantineUntil: expiry,
          statusBadgeText: 'Device Quarantined (Minor Safety Policy)',
        );
      } else {
        await prefs.remove(quarantineKey);
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
      // 180-Day Hardware Quarantine
      final quarantineUntil = now.add(const Duration(days: 180));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(quarantineKey, quarantineUntil.millisecondsSinceEpoch);

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
    state = state.copyWith(isQuarantined: false, quarantineUntil: null);
  }
}

final ageGateControllerProvider =
    StateNotifierProvider<AgeGateController, AgeGateState>((ref) {
  return AgeGateController();
});
