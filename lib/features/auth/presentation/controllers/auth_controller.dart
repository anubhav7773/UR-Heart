import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';

/// Immutable state for Age Gate and Auth
class AuthState {
  final bool isSignInTab;
  final int? selectedDay;
  final int? selectedMonth;
  final int? selectedYear;
  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool isLoading;
  final String? errorMessage;
  final bool isUnderageBlocked;
  final int resendCooldownSeconds;
  final bool isMagicLinkVerified;

  const AuthState({
    this.isSignInTab = false,
    this.selectedDay,
    this.selectedMonth,
    this.selectedYear,
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.isLoading = false,
    this.errorMessage,
    this.isUnderageBlocked = false,
    this.resendCooldownSeconds = 45,
    this.isMagicLinkVerified = false,
  });

  bool get hasSelectedFullDob =>
      selectedDay != null && selectedMonth != null && selectedYear != null;

  int? get calculatedAge {
    final day = selectedDay;
    final month = selectedMonth;
    final year = selectedYear;
    if (day == null || month == null || year == null) return null;

    final now = DateTime.now();
    int age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }

  bool get isAdult {
    final age = calculatedAge;
    return age != null && age >= 18;
  }

  bool get canSubmit {
    if (isSignInTab) {
      return email.isNotEmpty && password.length >= 6;
    }
    return hasSelectedFullDob &&
        isAdult &&
        email.isNotEmpty &&
        password.length >= 6 &&
        !isUnderageBlocked;
  }

  AuthState copyWith({
    bool? isSignInTab,
    int? selectedDay,
    int? selectedMonth,
    int? selectedYear,
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? isLoading,
    String? errorMessage,
    bool? isUnderageBlocked,
    int? resendCooldownSeconds,
    bool? isMagicLinkVerified,
  }) {
    return AuthState(
      isSignInTab: isSignInTab ?? this.isSignInTab,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isUnderageBlocked: isUnderageBlocked ?? this.isUnderageBlocked,
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
      isMagicLinkVerified: isMagicLinkVerified ?? this.isMagicLinkVerified,
    );
  }
}

/// Controller coordinating Neutral Age Gate, Auth validation, and Cooldown timer
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  Timer? _timer;

  AuthController(this._repository) : super(const AuthState());

  void setAuthTab({required bool isSignIn}) {
    state = state.copyWith(isSignInTab: isSignIn, errorMessage: null);
  }

  void setDateOfBirth({
    required int day,
    required int month,
    required int year,
  }) {
    final now = DateTime.now();
    int age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }

    final isUnderage = age < 18;
    state = state.copyWith(
      selectedDay: day,
      selectedMonth: month,
      selectedYear: year,
      isUnderageBlocked: isUnderage,
      errorMessage: isUnderage
          ? 'Underage Access Denied: UR-Heart is strictly for verified adults (18+).'
          : null,
    );
  }

  void setEmail(String email) {
    state = state.copyWith(email: email.trim());
  }

  void setPassword(String password) {
    state = state.copyWith(password: password);
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  Future<bool> submitRegistration() async {
    if (!state.canSubmit) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    final day = state.selectedDay;
    final month = state.selectedMonth;
    final year = state.selectedYear;
    final age = state.calculatedAge;

    if (day == null || month == null || year == null || age == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please select a complete Date of Birth.',
      );
      return false;
    }

    final dob = DateTime(year, month, day);
    final result = await _repository.registerIntent(
      email: state.email,
      dob: dob,
      calculatedAge: age,
    );

    state = state.copyWith(
      isLoading: false,
      isUnderageBlocked: result.isUnderageQuarantined,
      errorMessage: result.errorMessage,
    );

    if (result.isSuccess) {
      startCooldownTimer();
      return true;
    }
    return false;
  }

  void startCooldownTimer() {
    _timer?.cancel();
    state = state.copyWith(resendCooldownSeconds: 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCooldownSeconds > 0) {
        state = state.copyWith(
          resendCooldownSeconds: state.resendCooldownSeconds - 1,
        );
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> resendVerificationEmail() async {
    if (state.resendCooldownSeconds > 0) return;
    await _repository.resendVerificationEmail(state.email);
    startCooldownTimer();
  }

  void simulateMagicLinkConfirmation() {
    state = state.copyWith(isMagicLinkVerified: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});
