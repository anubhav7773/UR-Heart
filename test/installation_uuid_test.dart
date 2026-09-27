import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/network/api_interceptors.dart';
import 'package:ur_heart/core/security/installation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    InstallationService.clearMemoryCache();
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 Exit Criterion 3: Sandbox UUID Verification', () {
    test('Generates valid cryptographically random UUID v4 and persists to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      InstallationService.clearMemoryCache();

      final uuid = await InstallationService.getInstallationUuid();

      // Check UUID v4 format: 8-4-4-4-12 hex characters
      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidV4Regex.hasMatch(uuid), true,
          reason: 'Generated UUID must be a valid UUID v4 format');

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ur_heart_installation_uuid'), uuid);

      // Verify in-memory cache returns identical UUID
      final secondCallUuid = await InstallationService.getInstallationUuid();
      expect(secondCallUuid, uuid);
    });

    test('ApiInterceptors injects X-Installation-UUID header into Dio requests',
        () async {
      SharedPreferences.setMockInitialValues({});
      InstallationService.clearMemoryCache();

      final expectedUuid = await InstallationService.getInstallationUuid();

      final dio = Dio();
      dio.interceptors.add(ApiInterceptors(
        authTokenProvider: () async => 'test-jwt-token-xyz',
      ));

      // Use a custom adapter or capture the options in an onRequest check
      RequestOptions? capturedOptions;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          },
        ),
      );

      try {
        await dio.get<dynamic>('https://example.com/test');
      } catch (_) {
        // Expected since we aborted request in interceptor
      }

      expect(capturedOptions, isNotNull);
      expect(
        capturedOptions?.headers['X-Installation-UUID'],
        expectedUuid,
        reason: 'X-Installation-UUID header must match the sandbox installation UUID',
      );
      expect(
        capturedOptions?.headers['Authorization'],
        'Bearer test-jwt-token-xyz',
        reason: 'Bearer JWT token must be injected when authenticated',
      );
    });

    test('ApiInterceptors does not inject Authorization when no token is present',
        () async {
      SharedPreferences.setMockInitialValues({});
      InstallationService.clearMemoryCache();

      final dio = Dio();
      dio.interceptors.add(ApiInterceptors(
        authTokenProvider: () async => null,
      ));

      RequestOptions? capturedOptions;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          },
        ),
      );

      try {
        await dio.get<dynamic>('https://example.com/test');
      } catch (_) {
        // Expected
      }

      expect(capturedOptions, isNotNull);
      expect(capturedOptions?.headers.containsKey('Authorization'), false);
      expect(capturedOptions?.headers.containsKey('X-Installation-UUID'), true);
    });
  });
}
