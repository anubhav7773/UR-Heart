/// Translates Clerk API error codes and exceptions into clean, user-friendly messages.
class ClerkErrorMapper {
  /// Maps raw error codes or exceptions to human-readable text
  static String mapError(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    final errorString = error.toString().toLowerCase();

    // 1. Identification & User Not Found
    if (errorString.contains('form_identifier_not_found') ||
        errorString.contains('user not found') ||
        errorString.contains('identifier_not_found')) {
      return 'No account found with this email, phone, or username.';
    }

    // 2. Password Errors
    if (errorString.contains('form_password_incorrect') ||
        errorString.contains('password_incorrect') ||
        errorString.contains('invalid password')) {
      return 'Incorrect password. Please verify and try again.';
    }
    if (errorString.contains('form_password_pwned') ||
        errorString.contains('password_pwned')) {
      return 'This password has been found in a data breach. Please choose a stronger, unique password.';
    }
    if (errorString.contains('form_password_length_too_short') ||
        errorString.contains('password_too_short')) {
      return 'Password must be at least 8 characters long.';
    }

    // 3. OTP & Verification Code Errors
    if (errorString.contains('form_code_incorrect') ||
        errorString.contains('code_incorrect') ||
        errorString.contains('invalid verification code')) {
      return 'Invalid 6-digit verification code. Please check and try again.';
    }
    if (errorString.contains('form_code_expired') ||
        errorString.contains('code_expired') ||
        errorString.contains('verification expired')) {
      return 'Verification code has expired. Please request a new OTP.';
    }

    // 4. Session & Conflict Errors
    if (errorString.contains('session_exists') ||
        errorString.contains('already logged in')) {
      return 'Active session already exists. Refreshing authentication...';
    }
    if (errorString.contains('form_identifier_exists') ||
        errorString.contains('user already exists') ||
        errorString.contains('email_address_exists') ||
        errorString.contains('phone_number_exists')) {
      return 'An account with this email or phone already exists. Please sign in.';
    }

    // 5. Rate Limiting & Network
    if (errorString.contains('too_many_requests') ||
        errorString.contains('rate_limit_exceeded') ||
        errorString.contains('429')) {
      return 'Too many attempts. Please wait a few moments before trying again.';
    }
    if (errorString.contains('network') ||
        errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('timeout')) {
      return 'Unable to connect to servers. Please check your internet connection.';
    }

    // 6. Generic Fallback
    return 'Authentication failed. Please verify your credentials and try again.';
  }
}
