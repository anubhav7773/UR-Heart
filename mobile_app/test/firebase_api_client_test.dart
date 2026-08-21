import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/core/network/environment_config.dart';
import 'package:ruralheart_mobile/core/network/firebase_auth_interceptor.dart';
import 'package:ruralheart_mobile/core/network/user_repository.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString('{"success": true, "data": {}}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnvironmentConfig Tests', () {
    test('Resolves base URLs properly', () {
      EnvironmentConfig.setEnvironment(Environment.production);
      expect(EnvironmentConfig.baseUrl, equals('https://ur-heart.onrender.com/api/v1'));

      EnvironmentConfig.setEnvironment(Environment.development);
      expect(EnvironmentConfig.baseUrl, contains('8000/api/v1'));
    });
  });

  group('FirebaseAuthInterceptor Tests', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;

      dio.interceptors.add(
        FirebaseAuthInterceptor(
          tokenProvider: () async => 'mock_firebase_id_token_777',
        ),
      );
    });

    test('Injects Authorization Bearer and custom headers', () async {
      await dio.get('/test');

      expect(mockAdapter.lastOptions, isNotNull);
      expect(mockAdapter.lastOptions!.headers['Authorization'], equals('Bearer mock_firebase_id_token_777'));
      expect(mockAdapter.lastOptions!.headers['Accept'], equals('application/json'));
      expect(mockAdapter.lastOptions!.headers['X-Client-Platform'], equals('flutter'));
    });
  });

  group('UserProfileModel Tests', () {
    test('Deserializes backend JSON response correctly', () {
      final json = {
        'id': 'user_guid_123',
        'firebase_uid': 'firebase_uid_456',
        'email': 'priya@ruralheart.com',
        'full_name': 'Priya Sharma',
        'first_name': 'Priya',
        'age': 23,
        'bio': 'Lover of art and mountains.',
        'area_name': 'Varanasi',
        'village_pin_code': '221001',
        'gender': 'female',
        'interested_in': 'male',
        'intent': 'serious',
        'photos': ['https://r2.ruralheart.com/priya.webp'],
        'is_verified': true,
        'is_admin': false,
        'is_online': true,
        'is_onboarded': true,
      };

      final profile = UserProfileModel.fromJson(json);

      expect(profile.id, equals('user_guid_123'));
      expect(profile.firebaseUid, equals('firebase_uid_456'));
      expect(profile.fullName, equals('Priya Sharma'));
      expect(profile.isVerified, isTrue);
      expect(profile.isOnboarded, isTrue);
    });
  });
}
