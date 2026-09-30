import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/activity_logger_service.dart';
import '../../data/auth_repository.dart';
import 'age_gate_controller.dart';

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
  final bool isGoogleLoading;
  final String? errorMessage;
  final bool isUnderageBlocked;
  final int resendCooldownSeconds;
  final bool isMagicLinkVerified;
  final String? authenticatedUserId;
  final String? authenticatedDisplayName;
  final String? authenticatedPhotoUrl;
  final String? dispatchedPasskey;
  final String? magicLinkUrl;

  const AuthState({
    this.isSignInTab = false,
    this.selectedDay,
    this.selectedMonth,
    this.selectedYear,
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.isLoading = false,
    this.isGoogleLoading = false,
    this.errorMessage,
    this.isUnderageBlocked = false,
    this.resendCooldownSeconds = 45,
    this.isMagicLinkVerified = false,
    this.authenticatedUserId,
    this.authenticatedDisplayName,
    this.authenticatedPhotoUrl,
    this.dispatchedPasskey,
    this.magicLinkUrl,
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
    // Strict 18+ Age Gate: Mandatory across both Create Sanctuary and Sign In tabs
    if (!hasSelectedFullDob || !isAdult || isUnderageBlocked) {
      return false;
    }
    return email.isNotEmpty && password.length >= 6;
  }

  String get userId => authenticatedUserId ?? '';

  AuthState copyWith({
    bool? isSignInTab,
    int? selectedDay,
    int? selectedMonth,
    int? selectedYear,
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? isLoading,
    bool? isGoogleLoading,
    String? errorMessage,
    bool? isUnderageBlocked,
    int? resendCooldownSeconds,
    bool? isMagicLinkVerified,
    String? authenticatedUserId,
    String? authenticatedDisplayName,
    String? authenticatedPhotoUrl,
    String? dispatchedPasskey,
    String? magicLinkUrl,
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
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      errorMessage: errorMessage,
      isUnderageBlocked: isUnderageBlocked ?? this.isUnderageBlocked,
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
      isMagicLinkVerified: isMagicLinkVerified ?? this.isMagicLinkVerified,
      authenticatedUserId: authenticatedUserId ?? this.authenticatedUserId,
      authenticatedDisplayName:
          authenticatedDisplayName ?? this.authenticatedDisplayName,
      authenticatedPhotoUrl:
          authenticatedPhotoUrl ?? this.authenticatedPhotoUrl,
      dispatchedPasskey: dispatchedPasskey ?? this.dispatchedPasskey,
      magicLinkUrl: magicLinkUrl ?? this.magicLinkUrl,
    );
  }
}

/// Controller coordinating Neutral Age Gate, Auth validation, Google One Tap, and Cooldown timer
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  Timer? _timer;

  AuthController(this._repository) : super(const AuthState());

  void setAuthTab({required bool isSignIn}) {
    state = state.copyWith(isSignInTab: isSignIn, errorMessage: null);
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

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
    final mName = (month >= 1 && month <= 12) ? _monthNames[month - 1] : 'Jan';
    final formattedDob = '$day $mName $year';

    state = state.copyWith(
      selectedDay: day,
      selectedMonth: month,
      selectedYear: year,
      isUnderageBlocked: isUnderage,
      errorMessage: isUnderage
          ? 'Underage Access Denied: UR-Heart is strictly for verified adults (18+).'
          : null,
    );

    // Persist real selected DOB & age immediately to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ur_heart_selected_dob', formattedDob);
      prefs.setString('profile_dob', formattedDob);
      prefs.setInt('profile_age', age);
      prefs.setInt('ur_heart_user_age', age);
      prefs.setInt('ur_heart_dob_day', day);
      prefs.setInt('ur_heart_dob_month', month);
      prefs.setInt('ur_heart_dob_year', year);
    });

    // Stream activity to Render backend
    ActivityLogger.log(
      category: 'AUTH',
      action: 'DATE_OF_BIRTH_SELECTED',
      screen: 'AgeGateAuthScreen',
      details: {
        'formatted_dob': formattedDob,
        'calculated_age': age,
        'is_adult': !isUnderage,
      },
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

  /// Triggers 100% Production-Grade Google One Tap / Sign-In Flow
  Future<AuthResult> signInWithGoogle() async {
    // 1. Minor Safety Quarantine Pre-Check
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(AgeGateController.quarantineKey);
    if (millis != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(millis);
      if (DateTime.now().isBefore(expiry)) {
        state = state.copyWith(
          isUnderageBlocked: true,
          errorMessage:
              'Access Denied: Device is currently under minor safety quarantine.',
        );
        return AuthResult.underageBlocked();
      }
    }

    // 2. Strict 18+ Gatekeeper Check: User MUST select DOB & be 18+
    if (!state.hasSelectedFullDob || !state.isAdult || state.isUnderageBlocked) {
      state = state.copyWith(
        errorMessage:
            'Strict 18+ Age Gate: Please select your Date of Birth above and confirm you are 18+ before proceeding with Google Sign-In.',
      );
      return AuthResult.failure(
        'Age verification required: You must be 18+ to enter UR-Heart.',
      );
    }

    // 3. Set loading state
    state = state.copyWith(isGoogleLoading: true, errorMessage: null);

    try {
      final result = await _repository.signInWithGoogle();

      if (result.isCancelled) {
        state = state.copyWith(isGoogleLoading: false);
        return result;
      }

      if (!result.isSuccess) {
        state = state.copyWith(
          isGoogleLoading: false,
          errorMessage: result.errorMessage ?? 'Google Sign-In failed.',
        );
        return result;
      }

      state = state.copyWith(
        isGoogleLoading: false,
        email: result.email ?? state.email,
        authenticatedUserId: result.userId,
        authenticatedDisplayName: result.displayName,
        authenticatedPhotoUrl: result.photoUrl,
        errorMessage: null,
      );

      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final mName = (state.selectedMonth != null && state.selectedMonth! >= 1 && state.selectedMonth! <= 12)
          ? monthNames[state.selectedMonth! - 1]
          : 'Jan';
      final formattedDob = '${state.selectedDay} $mName ${state.selectedYear}';
      await prefs.setString('ur_heart_selected_dob', formattedDob);
      await prefs.setString('profile_dob', formattedDob);

      return result;
    } catch (e) {
      state = state.copyWith(
        isGoogleLoading: false,
        errorMessage: 'An unexpected error occurred during Google Sign-In.',
      );
      return AuthResult.failure(e.toString());
    }
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
      // 1. Dispatch backend magic link
      final magicRes = await _repository.sendMagicLink(state.email);
      final passkey = magicRes?['passkey']?.toString();
      final magicUrl = magicRes?['magic_link']?.toString();
      state = state.copyWith(
        dispatchedPasskey: passkey,
        magicLinkUrl: magicUrl,
      );

      // 2. Direct Mobile Client Dispatch via Firebase Console
      try {
        await FirebaseAuth.instance.sendSignInLinkToEmail(
          email: state.email,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://ur-heart-44b46.firebaseapp.com',
            handleCodeInApp: true,
            androidPackageName: 'com.urheart.app',
            androidInstallApp: true,
            androidMinimumVersion: '21',
          ),
        );
        debugPrint('[AUTH] Firebase client-side email link dispatched to: ${state.email}');
      } catch (fbErr) {
        debugPrint('[AUTH] Firebase client sendSignInLinkToEmail notice: $fbErr');
      }

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

  Future<void> resendVerificationEmail([String? overrideEmail]) async {
    if (state.resendCooldownSeconds > 0) return;
    final targetEmail = overrideEmail ?? state.email;
    final magicRes = await _repository.sendMagicLink(targetEmail);
    final passkey = magicRes?['passkey']?.toString();
    final magicUrl = magicRes?['magic_link']?.toString();
    state = state.copyWith(
      dispatchedPasskey: passkey,
      magicLinkUrl: magicUrl,
    );

    // Direct Mobile Client Dispatch via Firebase Console
    try {
      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: targetEmail,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://ur-heart-44b46.firebaseapp.com',
          handleCodeInApp: true,
          androidPackageName: 'com.urheart.app',
          androidInstallApp: true,
          androidMinimumVersion: '21',
        ),
      );
      debugPrint('[AUTH] Firebase client-side email link resent to: $targetEmail');
    } catch (fbErr) {
      debugPrint('[AUTH] Firebase client sendSignInLinkToEmail notice: $fbErr');
    }

    startCooldownTimer();
  }

  void simulateMagicLinkConfirmation() {
    state = state.copyWith(isMagicLinkVerified: true);
  }

  /// Verifies magic link token with repository
  Future<bool> verifyMagicLink(String tokenOrPasskey, {String? email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _repository.verifyMagicLinkToken(tokenOrPasskey, email: email ?? state.email);
      final success = res != null;
      state = state.copyWith(
        isLoading: false,
        isMagicLinkVerified: success,
        email: res?['email']?.toString() ?? (email ?? state.email),
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Magic link verification failed.',
      );
      return false;
    }
  }

  /// Actively checks if user has tapped the magic link in their email
  Future<bool> pollVerificationStatus(String email) async {
    try {
      final res = await _repository.checkVerificationStatus(email);
      if (res != null && res['is_verified'] == true) {
        state = state.copyWith(
          isMagicLinkVerified: true,
          email: res['email']?.toString() ?? email,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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
