import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/core/network/clerk_auth_interceptor.dart';
import 'package:ruralheart_mobile/core/network/secure_api_client.dart';
import 'package:ruralheart_mobile/core/network/user_repository.dart';
import 'package:ruralheart_mobile/core/security/storage_manager.dart';
import 'package:ruralheart_mobile/features/auth/controllers/auth_controller.dart';
import 'package:ruralheart_mobile/features/auth/controllers/auth_state.dart';
import 'package:ruralheart_mobile/features/auth/services/clerk_auth_service.dart';

/// Mock HTTP Adapter to capture transmitted headers and simulate FastAPI `/api/v1/users/me` response
class MockFastAPIAdapter implements HttpClientAdapter {
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;

    if (options.path.contains('/users/me')) {
      final jsonString = '''
      {
        "success": true,
        "message": "User profile retrieved successfully.",
        "data": {
          "id": "22222222-3333-4444-5555-666666666666",
          "user_id": "22222222-3333-4444-5555-666666666666",
          "clerk_id": "user_clerk_test_e2e_888",
          "email": "e2e.tester@ruralheart.com",
          "full_name": "Karan Malhotra",
          "first_name": "Karan",
          "age": 25,
          "bio": "Coffee, technology, and traveling across UP.",
          "area_name": "Ayodhya",
          "village_pin_code": "224001",
          "gender": "male",
          "interested_in": "female",
          "intent": "serious",
          "photos": ["https://r2.ruralheart.com/karan.webp"],
          "is_verified": true,
          "is_admin": false,
          "is_online": true,
          "is_onboarded": true
        }
      }
      ''';
      return ResponseBody.fromString(
        jsonString,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString('{"success": true}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: End-to-End Clerk Auth & Transmission Pipeline Tests', () {
    late MockFastAPIAdapter mockHttpAdapter;
    late SecureApiClient apiClient;
    late UserRepository userRepository;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      mockHttpAdapter = MockFastAPIAdapter();
      apiClient = SecureApiClient.instance;
      apiClient.dio.httpClientAdapter = mockHttpAdapter;
      userRepository = UserRepository(apiClient: apiClient);
    });

    test('Full E2E Handshake: Login -> Token Cache -> Dio Interceptor Injection -> /users/me Parse', () async {
      const mockClerkJWT = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.e2e_test_session_token_xyz';

      // 1. Client login stores token
      await StorageManager.instance.saveAuthToken(mockClerkJWT);
      await StorageManager.instance.saveUserId('user_clerk_test_e2e_888');

      // 2. Transmit request through UserRepository -> SecureApiClient -> ClerkAuthInterceptor
      final UserProfileModel profile = await userRepository.fetchCurrentUserProfile();

      // 3. Verify Dio Interceptor Headers
      final capturedOptions = mockHttpAdapter.lastRequestOptions;
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers['Authorization'], equals('Bearer $mockClerkJWT'));
      expect(capturedOptions.headers['Accept'], equals('application/json'));
      expect(capturedOptions.headers['X-Client-Platform'], equals('flutter'));

      // 4. Verify deserialized UserProfileModel matching FastAPI DB response
      expect(profile.clerkId, equals('user_clerk_test_e2e_888'));
      expect(profile.fullName, equals('Karan Malhotra'));
      expect(profile.email, equals('e2e.tester@ruralheart.com'));
      expect(profile.isVerified, isTrue);
      expect(profile.isOnboarded, isTrue);
    });
  });
}
