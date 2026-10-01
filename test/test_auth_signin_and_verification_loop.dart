import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/core/storage/secure_session_storage.dart';
import 'package:ur_heart/features/auth/data/auth_repository.dart';
import 'package:ur_heart/features/auth/presentation/controllers/auth_controller.dart';
import 'package:ur_heart/features/auth/presentation/screens/age_gate_auth_screen.dart';
import 'package:ur_heart/features/auth/presentation/screens/magic_link_screen.dart';

class MockAuthRepository extends AuthRepository {
  MockAuthRepository() : super(ApiClient());

  int signInWithPasswordCallCount = 0;
  int submitRegistrationCallCount = 0;
  int resendEmailCallCount = 0;
  bool nextSignInSuccess = true;
  bool nextIsProfileCompleted = true;

  @override
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInWithPasswordCallCount++;
    if (nextSignInSuccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_auth_token', 'mock_jwt_token_123');
      await prefs.setString('ur_heart_user_email', email);
      await prefs.setBool('ur_heart_consent_given', true);
      await prefs.setBool('ur_heart_theme_locked', true);
      if (nextIsProfileCompleted) {
        await prefs.setBool('ur_heart_profile_setup_completed', true);
      }
      await SecureSessionStorage.instance.saveAuthToken('mock_jwt_token_123');
      await SecureSessionStorage.instance.saveUserSession(
        userId: 'mock_uid_123',
        email: email,
        isProfileCompleted: nextIsProfileCompleted,
      );
      return AuthResult.success(
        userId: 'mock_uid_123',
        email: email,
        isProfileCompleted: nextIsProfileCompleted,
      );
    }
    return AuthResult.failure('Invalid credentials');
  }

  @override
  Future<AuthResult> registerIntent({
    required String email,
    required DateTime dob,
    required int calculatedAge,
  }) async {
    submitRegistrationCallCount++;
    return AuthResult.success();
  }

  @override
  Future<Map<String, dynamic>?> sendMagicLink(String email) async {
    resendEmailCallCount++;
    return {
      'status': 'sent',
      'email': email,
      'passkey': '123456',
      'magic_link': 'https://urheart.asiverticals.me/api/v1/auth/verify?token=mock_tok',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Issue 7: Sign-In and Verification Loop Resolution', () {
    testWidgets('AuthController.signInWithPassword authenticates, saves tokens and updates state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockRepo = MockAuthRepository();
      final controller = AuthController(mockRepo);

      // Set valid adult DOB and credentials
      controller.setDateOfBirth(day: 15, month: 6, year: 1998);
      controller.setEmail('seeker@urheart.app');
      controller.setPassword('securepass123');
      await tester.pump(const Duration(milliseconds: 100));

      final result = await controller.signInWithPassword();
      await tester.pump(const Duration(milliseconds: 100));

      expect(result.isSuccess, isTrue);
      expect(result.userId, equals('mock_uid_123'));
      expect(controller.state.authenticatedUserId, equals('mock_uid_123'));
      expect(mockRepo.signInWithPasswordCallCount, equals(1));

      // Verify SecureSessionStorage has auth token
      final secureToken = await SecureSessionStorage.instance.getAuthToken();
      expect(secureToken, equals('mock_jwt_token_123'));

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ur_heart_consent_given'), isTrue);
      expect(prefs.getBool('ur_heart_theme_locked'), isTrue);
    });


    testWidgets('AgeGateAuthScreen on Sign In tab calls signInWithPassword instead of submitRegistration', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockRepo = MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: const AgeGateAuthScreen(),
            routes: {
              '/main': (context) => const Scaffold(body: Text('Main Shell Screen')),
              '/profile-setup': (context) => const Scaffold(body: Text('Profile Setup Screen')),
              '/verify-email': (context) => const Scaffold(body: Text('Verify Email Screen')),
            },
          ),
        ),
      );


      // Verify tab switcher exists and tap Sign In
      final signInTabFinder = find.text('Sign In');
      expect(signInTabFinder, findsOneWidget);
      await tester.tap(signInTabFinder);
      await tester.pumpAndSettle();

      // Enter adult DOB
      final element = tester.element(find.byType(AgeGateAuthScreen));
      final container = ProviderScope.containerOf(element);
      container.read(authControllerProvider.notifier).setDateOfBirth(day: 10, month: 5, year: 1995);
      container.read(authControllerProvider.notifier).setEmail('verified@urheart.app');
      container.read(authControllerProvider.notifier).setPassword('sanctuary_pass_123');
      await tester.pumpAndSettle();

      // Tap "Enter Sanctuary ➔"
      final enterButtonFinder = find.text('Enter Sanctuary ➔');
      expect(enterButtonFinder, findsOneWidget);
      await tester.tap(enterButtonFinder);
      await tester.pumpAndSettle();

      // Confirm signInWithPassword was invoked, NOT submitRegistration
      expect(mockRepo.signInWithPasswordCallCount, equals(1));
      expect(mockRepo.submitRegistrationCallCount, equals(0));
      expect(mockRepo.resendEmailCallCount, equals(0));
    });

    testWidgets('MagicLinkScreen does NOT automatically resend verification email upon mounting', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockRepo = MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MagicLinkScreen(email: 'user@urheart.app'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm no auto-resend occurred on screen load
      expect(mockRepo.resendEmailCallCount, equals(0));
    });
  });
}
