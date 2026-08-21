/// Unified State Hierarchy for Authentication Lifecycle
abstract class AuthState {
  const AuthState();
}

/// Initial Idle State
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Active Processing / Loading State
class AuthLoading extends AuthState {
  final String? loadingMessage;
  const AuthLoading({this.loadingMessage});
}

/// Two-Step Phone OTP Required State
class AuthOTPRequired extends AuthState {
  final String phoneNumber;
  final int resendCountdown;

  const AuthOTPRequired({
    required this.phoneNumber,
    this.resendCountdown = 30,
  });
}

/// Successful Authentication State
class AuthAuthenticated extends AuthState {
  final String token;
  final String userId;
  final bool isProfileComplete;

  const AuthAuthenticated({
    required this.token,
    required this.userId,
    this.isProfileComplete = false,
  });
}

/// Error / Authentication Failure State
class AuthError extends AuthState {
  final String errorMessage;
  final bool canRetry;

  const AuthError({
    required this.errorMessage,
    this.canRetry = true,
  });
}
