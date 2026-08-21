import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/features/auth/controllers/auth_controller.dart';
import 'package:ruralheart_mobile/features/auth/controllers/auth_state.dart';
import 'package:ruralheart_mobile/features/auth/services/firebase_auth_service.dart';

class MockFirebaseAuthService implements FirebaseAuthService {
  bool shouldSucceed = true;
  String mockToken = 'mock_firebase_jwt_123';
  String mockUserId = 'user_firebase_mock_999';

  @override
  String? pendingPhoneNumber;

  @override
  String? verificationId = 'mock_verification_id_123';

  @override
  User? currentUser;

  @override
  Future<AuthResult> signInWithGoogle() async {
    if (shouldSucceed) {
      return AuthResult.success(token: mockToken, userId: mockUserId);
    }
    return AuthResult.failure('Google sign-in was cancelled.');
  }

  @override
  Future<AuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (shouldSucceed) {
      return AuthResult.success(token: mockToken, userId: mockUserId);
    }
    return AuthResult.failure('Incorrect credentials. Please verify and try again.');
  }

  @override
  Future<AuthResult> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (shouldSucceed) {
      return AuthResult.success(token: mockToken, userId: mockUserId);
    }
    return AuthResult.failure('An account already exists with this email address.');
  }

  @override
  Future<bool> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onVerificationFailed,
  }) async {
    if (shouldSucceed) {
      pendingPhoneNumber = phoneNumber;
      onCodeSent('mock_verification_id_123', null);
      return true;
    } else {
      onVerificationFailed('Invalid phone number format.');
      return false;
    }
  }

  @override
  Future<AuthResult> verifyPhoneOTP({
    required String otpCode,
    String? customVerificationId,
  }) async {
    if (shouldSucceed && otpCode == '123456') {
      return AuthResult.success(token: mockToken, userId: mockUserId);
    }
    return AuthResult.failure('Invalid or expired OTP verification code.');
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController Native Firebase Auth Tests', () {
    late MockFirebaseAuthService mockService;
    late AuthController controller;

    setUp(() {
      mockService = MockFirebaseAuthService();
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
      expect(authState.token, equals('mock_firebase_jwt_123'));
      expect(authState.userId, equals('user_firebase_mock_999'));
    });

    test('signInWithPassword failure transitions to AuthError', () async {
      mockService.shouldSucceed = false;
      await controller.signInWithPassword(email: 'test@example.com', password: 'wrong_pass');

      expect(controller.state, isA<AuthError>());
      final errorState = controller.state as AuthError;
      expect(errorState.errorMessage, contains('Incorrect credentials'));
    });

    test('Phone OTP lifecycle transitions: AuthInitial -> AuthOTPRequired -> AuthAuthenticated', () async {
      mockService.shouldSucceed = true;

      final sent = await controller.sendPhoneOTP('+919876543210');
      expect(sent, isTrue);
      expect(controller.state, isA<AuthOTPRequired>());
      final otpState = controller.state as AuthOTPRequired;
      expect(otpState.phoneNumber, equals('+919876543210'));

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
