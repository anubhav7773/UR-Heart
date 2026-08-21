import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';
import 'auth_state.dart';

/// Unified Authentication Controller & State Notifier for Project UR-Heart.
/// Manages Firebase Authentication state transitions, auto-retries, and token distribution.
class AuthController extends ChangeNotifier {
  final FirebaseAuthService _authService;

  AuthState _state = const AuthInitial();
  AuthState get state => _state;

  bool get isLoading => _state is AuthLoading;
  bool get isAuthenticated => _state is AuthAuthenticated;

  AuthController({FirebaseAuthService? authService})
      : _authService = authService ?? FirebaseAuthService.instance;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Resets back to clean initial state
  void resetState() {
    _setState(const AuthInitial());
  }

  // ===========================================================================
  // 1. Google Sign-In Dispatch
  // ===========================================================================
  Future<void> signInWithGoogle() async {
    _setState(const AuthLoading(loadingMessage: 'Signing in with Google...'));

    try {
      final result = await _authService.signInWithGoogle();
      if (result.isSuccess) {
        _setState(AuthAuthenticated(
          token: result.token!,
          userId: result.userId!,
          isProfileComplete: result.isProfileComplete,
        ));
      } else {
        _setState(AuthError(errorMessage: result.errorMessage ?? 'Google sign-in failed.'));
      }
    } catch (e) {
      _setState(AuthError(errorMessage: e.toString()));
    }
  }

  // ===========================================================================
  // 2. Email & Password Dispatch
  // ===========================================================================
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _setState(const AuthLoading(loadingMessage: 'Signing in with email...'));

    try {
      final result = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      if (result.isSuccess) {
        _setState(AuthAuthenticated(
          token: result.token!,
          userId: result.userId!,
          isProfileComplete: result.isProfileComplete,
        ));
      } else {
        _setState(AuthError(errorMessage: result.errorMessage ?? 'Email login failed.'));
      }
    } catch (e) {
      _setState(AuthError(errorMessage: e.toString()));
    }
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    _setState(const AuthLoading(loadingMessage: 'Creating your account...'));

    try {
      final result = await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
      );
      if (result.isSuccess) {
        _setState(AuthAuthenticated(
          token: result.token!,
          userId: result.userId!,
          isProfileComplete: result.isProfileComplete,
        ));
      } else {
        _setState(AuthError(errorMessage: result.errorMessage ?? 'Sign up failed.'));
      }
    } catch (e) {
      _setState(AuthError(errorMessage: e.toString()));
    }
  }

  // ===========================================================================
  // 3. Phone & SMS OTP Dispatch (Firebase verifyPhoneNumber)
  // ===========================================================================
  Future<bool> sendPhoneOTP(String phoneNumber) async {
    _setState(const AuthLoading(loadingMessage: 'Sending verification OTP...'));

    try {
      final sent = await _authService.sendPhoneOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          _setState(AuthOTPRequired(phoneNumber: phoneNumber));
        },
        onVerificationFailed: (errorMessage) {
          _setState(AuthError(errorMessage: errorMessage));
        },
      );
      return sent;
    } catch (e) {
      _setState(AuthError(errorMessage: e.toString()));
      return false;
    }
  }

  Future<void> verifyPhoneOTP(String otpCode, {String? verificationId}) async {
    _setState(const AuthLoading(loadingMessage: 'Verifying OTP code...'));

    try {
      final result = await _authService.verifyPhoneOTP(
        otpCode: otpCode,
        customVerificationId: verificationId,
      );
      if (result.isSuccess) {
        _setState(AuthAuthenticated(
          token: result.token!,
          userId: result.userId!,
          isProfileComplete: result.isProfileComplete,
        ));
      } else {
        _setState(AuthError(errorMessage: result.errorMessage ?? 'Verification failed.'));
      }
    } catch (e) {
      _setState(AuthError(errorMessage: e.toString()));
    }
  }

  // ===========================================================================
  // 4. Username / Handle Dispatch
  // ===========================================================================
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    // Normalizes handle to email handle fallback or calls email/pass
    final emailFallback = username.contains('@') ? username : '$username@ruralheart.app';
    await signInWithPassword(email: emailFallback, password: password);
  }

  // ===========================================================================
  // 5. Sign Out
  // ===========================================================================
  Future<void> signOut() async {
    await _authService.signOut();
    resetState();
  }
}
