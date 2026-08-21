import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/features/auth/controllers/auth_controller.dart';
import 'package:ruralheart_mobile/features/auth/controllers/auth_state.dart';
import 'package:ruralheart_mobile/features/auth/services/clerk_auth_service.dart';
import 'package:ruralheart_mobile/features/auth/services/clerk_error_mapper.dart';

/// Mock implementation of ClerkAuthService implementing interface
class MockClerkAuthService implements ClerkAuthService {
  bool shouldSucceed = true;
  String? mockToken = 'mock_jwt_session_12345';
  String? mockUserId = 'user_clerk_mock_999';

  @override
  String? pendingPhoneNumber;

  @override
  Future<ClerkAuthResult> signInWithGoogle() async {
    if (shouldSucceed) {
      return ClerkAuthResult.success(token: mockToken!, userId: mockUserId!);
    }
    return ClerkAuthResult.failure('Google OAuth failed');
  }

  @override
  Future<ClerkAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (shouldSucceed) {
      return ClerkAuthResult.success(token: mockToken!, userId: mockUserId!);
    }
    return ClerkAuthResult.failure(ClerkErrorMapper.mapError('form_password_incorrect'));
  }

  @override
  Future<ClerkAuthResult> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    if (shouldSucceed) {
      return ClerkAuthResult.success(token: mockToken!, userId: mockUserId!);
    }
    return ClerkAuthResult.failure(ClerkErrorMapper.mapError('form_identifier_exists'));
  }

  @override
  Future<bool> initiatePhoneSignIn(String phoneNumber) async {
    pendingPhoneNumber = phoneNumber;
    return shouldSucceed;
  }

  @override
  Future<ClerkAuthResult> verifyPhoneOTP(String otpCode) async {
    if (shouldSucceed && otpCode == '123456') {
      return ClerkAuthResult.success(token: mockToken!, userId: mockUserId!);
    }
    return ClerkAuthResult.failure(ClerkErrorMapper.mapError('form_code_incorrect'));
  }

  @override
  Future<ClerkAuthResult> signInWithUsername({
    required String username,
    required String password,
  }) async {
    if (shouldSucceed) {
      return ClerkAuthResult.success(token: mockToken!, userId: mockUserId!);
    }
    return ClerkAuthResult.failure(ClerkErrorMapper.mapError('form_password_incorrect'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClerkErrorMapper Tests', () {
    test('Maps standard Clerk API error codes to human-readable strings', () {
      expect(
        ClerkErrorMapper.mapError('form_identifier_not_found'),
        equals('No account found with this email, phone, or username.'),
      );
      expect(
        ClerkErrorMapper.mapError('form_password_incorrect'),
        equals('Incorrect password. Please verify and try again.'),
      );
      expect(
        ClerkErrorMapper.mapError('form_code_incorrect'),
        equals('Invalid 6-digit verification code. Please check and try again.'),
      );
    });
  });

  group('AuthController State Transition Tests', () {
    late MockClerkAuthService mockService;
    late AuthController controller;

    setUp(() {
      mockService = MockClerkAuthService();
      controller = AuthController(authService: mockService);
    });

    test('Initial state is AuthInitial', () {
      expect(controller.state, isA<AuthInitial>());
      expect(controller.isLoading, isFalse);
      expect(controller.isAuthenticated, isFalse);
    });

    test('signInWithGoogle transitions: AuthInitial -> AuthAuthenticated', () async {
      mockService.shouldSucceed = true;
      await controller.signInWithGoogle();

      expect(controller.state, isA<AuthAuthenticated>());
      final authState = controller.state as AuthAuthenticated;
      expect(authState.token, equals('mock_jwt_session_12345'));
      expect(authState.userId, equals('user_clerk_mock_999'));
    });

    test('signInWithPassword failure transitions to AuthError with mapped message', () async {
      mockService.shouldSucceed = false;
      await controller.signInWithPassword(email: 'test@example.com', password: 'wrong_password');

      expect(controller.state, isA<AuthError>());
      final errorState = controller.state as AuthError;
      expect(errorState.errorMessage, contains('Incorrect password'));
    });

    test('Phone OTP two-step lifecycle transitions: AuthInitial -> AuthOTPRequired -> AuthAuthenticated', () async {
      mockService.shouldSucceed = true;

      // 1. Step 1: Send OTP
      final sent = await controller.sendPhoneOTP('+919876543210');
      expect(sent, isTrue);
      expect(controller.state, isA<AuthOTPRequired>());
      final otpState = controller.state as AuthOTPRequired;
      expect(otpState.phoneNumber, equals('+919876543210'));

      // 2. Step 2: Verify OTP
      await controller.verifyPhoneOTP('123456');
      expect(controller.state, isA<AuthAuthenticated>());
    });

    test('resetState returns controller to AuthInitial', () async {
      await controller.signInWithGoogle();
      expect(controller.state, isA<AuthAuthenticated>());

      controller.resetState();
      expect(controller.state, isA<AuthInitial>());
    });
  });
}
