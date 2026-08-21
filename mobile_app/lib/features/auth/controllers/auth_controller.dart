import 'package:flutter/foundation.dart';
import '../services/clerk_auth_service.dart';
import '../services/clerk_error_mapper.dart';
import 'auth_state.dart';

/// Unified Authentication Controller & State Notifier for Project UR-Heart.
/// Manages state transitions, auto-retries, and token distribution for downstream interceptors.
class AuthController extends ChangeNotifier {
  final ClerkAuthService _authService;

  AuthState _state = const AuthInitial();
  AuthState get state => _state;

  bool get isLoading => _state is AuthLoading;
  bool get isAuthenticated => _state is AuthAuthenticated;

  AuthController({ClerkAuthService? authService})
      : _authService = authService ?? ClerkAuthService.instance;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Resets back to clean initial state
  void resetState() {
    _setState(const AuthInitial());
  }

  // ===========================================================================
  // 1. Google OAuth Dispatch
  // ===========================================================================
  Future<void> signInWithGoogle() async {
    _setState(const AuthLoading(loadingMessage: 'Connecting with Google...'));

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
      _setState(AuthError(errorMessage: ClerkErrorMapper.mapError(e)));
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
      final result = await _authService.signInWithPassword(
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
      _setState(AuthError(errorMessage: ClerkErrorMapper.mapError(e)));
    }
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    _setState(const AuthLoading(loadingMessage: 'Creating your account...'));

    try {
      final result = await _authService.signUpWithPassword(
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
      _setState(AuthError(errorMessage: ClerkErrorMapper.mapError(e)));
    }
  }

  // ===========================================================================
  // 3. Phone & SMS OTP Dispatch (Two-Step Lifecycle)
  // ===========================================================================
  Future<bool> sendPhoneOTP(String phoneNumber) async {
    _setState(const AuthLoading(loadingMessage: 'Sending verification OTP...'));

    try {
      final sent = await _authService.initiatePhoneSignIn(phoneNumber);
      if (sent) {
        _setState(AuthOTPRequired(phoneNumber: phoneNumber));
        return true;
      } else {
        _setState(const AuthError(errorMessage: 'Failed to dispatch OTP. Please check the number.'));
        return false;
      }
    } catch (e) {
      _setState(AuthError(errorMessage: ClerkErrorMapper.mapError(e)));
      return false;
    }
  }

  Future<void> verifyPhoneOTP(String otpCode) async {
    _setState(const AuthLoading(loadingMessage: 'Verifying OTP code...'));

    try {
      final result = await _authService.verifyPhoneOTP(otpCode);
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
      _setState(AuthError(errorMessage: ClerkErrorMapper.mapError(e)));
    }
  }

  // ===========================================================================
  // 4. Username Dispatch
  // ===========================================================================
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    _setState(const AuthLoading(loadingMessage: 'Authenticating username...'));

    try {
      final result = await _authService.signInWithUsername(
        username: username,
        password: password,
      );
      if (result.isSuccess) {
        _setState(AuthAuthenticated(
          token: result.token!,
          userId: result.userId!,
          isProfileComplete: result.isProfileComplete,
        ));
      } else {
        _setState(AuthError(errorMessage: result.errorMessage ?? 'Username login failed.'));
      }
    } catch (e) {
      _setState(AuthError(errorMessage: ClerkErrorMapper.mapError(e)));
    }
  }
}
