import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/features/auth/data/auth_repository.dart';
import 'package:ur_heart/features/auth/data/google_auth_service.dart';
import 'package:ur_heart/features/auth/presentation/controllers/age_gate_controller.dart';
import 'package:ur_heart/features/auth/presentation/controllers/auth_controller.dart';
import 'package:ur_heart/features/auth/presentation/widgets/google_sign_in_button.dart';

class MockGoogleAuthService extends GoogleAuthService {
  bool shouldSucceed = true;
  bool shouldCancel = false;
  String? mockError;

  @override
  Future<GoogleAuthResult> signIn() async {
    if (shouldCancel) {
      return GoogleAuthResult.cancelled();
    }
    if (!shouldSucceed) {
      return GoogleAuthResult.failure(mockError ?? 'Simulated auth failure');
    }
    return GoogleAuthResult.success(
      userId: 'mock_google_uid_123',
      email: 'sanctuary_user@gmail.com',
      displayName: 'Aarav Sharma',
      photoUrl: 'https://lh3.googleusercontent.com/a/mock_photo',
      idToken: 'mock_jwt_token',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Production Google Sign-In & One Tap Unit & Widget Tests', () {
    test('GoogleAuthResult factory constructors provide valid state envelopes', () {
      final success = GoogleAuthResult.success(
        userId: 'u123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      expect(success.isSuccess, isTrue);
      expect(success.isCancelled, isFalse);
      expect(success.userId, 'u123');
      expect(success.email, 'test@example.com');
      expect(success.displayName, 'Test User');

      final cancelled = GoogleAuthResult.cancelled();
      expect(cancelled.isSuccess, isFalse);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.errorMessage, isNull);

      final failure = GoogleAuthResult.failure('Network timeout');
      expect(failure.isSuccess, isFalse);
      expect(failure.isCancelled, isFalse);
      expect(failure.errorMessage, 'Network timeout');
    });

    testWidgets('GoogleSignInButton renders Google emblem, text, and responds to click',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GoogleSignInButton(
                isDark: true,
                isLoading: false,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GoogleLogoIcon), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('GoogleSignInButton displays progress indicator and disables taps during loading',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GoogleSignInButton(
                isDark: true,
                isLoading: true,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    test('AuthController signInWithGoogle updates state on successful Google authentication',
        () async {
      final mockGoogleAuth = MockGoogleAuthService();
      final repo = AuthRepository(ApiClient(), mockGoogleAuth);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final controller = container.read(authControllerProvider.notifier);

      final result = await controller.signInWithGoogle();

      expect(result.isSuccess, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isGoogleLoading, isFalse);
      expect(state.email, 'sanctuary_user@gmail.com');
      expect(state.authenticatedUserId, 'mock_google_uid_123');
      expect(state.authenticatedDisplayName, 'Aarav Sharma');
      expect(state.errorMessage, isNull);
    });

    test('AuthController signInWithGoogle handles user cancellation silently without scary error',
        () async {
      final mockGoogleAuth = MockGoogleAuthService()..shouldCancel = true;
      final repo = AuthRepository(ApiClient(), mockGoogleAuth);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final controller = container.read(authControllerProvider.notifier);

      final result = await controller.signInWithGoogle();

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isGoogleLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('AuthController signInWithGoogle denies access if device is under minor safety quarantine',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final futureQuarantine =
          DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch;
      await prefs.setInt(AgeGateController.quarantineKey, futureQuarantine);

      final mockGoogleAuth = MockGoogleAuthService();
      final repo = AuthRepository(ApiClient(), mockGoogleAuth);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final controller = container.read(authControllerProvider.notifier);

      final result = await controller.signInWithGoogle();

      expect(result.isSuccess, isFalse);
      expect(result.isUnderageQuarantined, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isUnderageBlocked, isTrue);
      expect(state.errorMessage, contains('Access Denied'));
    });
  });
}
