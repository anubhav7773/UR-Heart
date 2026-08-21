import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/core/auth/oauth_redirect_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OAuthRedirectHandler URI Parsing Tests', () {
    test('OAuthCallbackEvent parses successful Clerk OAuth callback URL correctly', () {
      final sampleUri = Uri.parse(
        'clerk://oauth_callback?code=clerk_auth_code_12345&state=random_state_xyz&session_token=jwt_mock_token_abcdef',
      );

      expect(sampleUri.scheme, equals('clerk'));
      expect(sampleUri.host, equals('oauth_callback'));
      expect(sampleUri.queryParameters['code'], equals('clerk_auth_code_12345'));
      expect(sampleUri.queryParameters['session_token'], equals('jwt_mock_token_abcdef'));

      final event = OAuthCallbackEvent(
        rawUri: sampleUri,
        isSuccess: true,
        code: sampleUri.queryParameters['code'],
        sessionToken: sampleUri.queryParameters['session_token'],
        state: sampleUri.queryParameters['state'],
      );

      expect(event.isSuccess, isTrue);
      expect(event.code, equals('clerk_auth_code_12345'));
      expect(event.sessionToken, equals('jwt_mock_token_abcdef'));
      expect(event.error, isNull);
    });

    test('OAuthCallbackEvent parses OAuth failure/cancellation callback correctly', () {
      final sampleUri = Uri.parse(
        'clerk://oauth_callback?error=access_denied&error_description=User+cancelled+Google+OAuth',
      );

      final event = OAuthCallbackEvent(
        rawUri: sampleUri,
        isSuccess: false,
        error: sampleUri.queryParameters['error'],
        errorDescription: sampleUri.queryParameters['error_description'],
      );

      expect(event.isSuccess, isFalse);
      expect(event.error, equals('access_denied'));
      expect(event.errorDescription, equals('User cancelled Google OAuth'));
    });
  });
}
