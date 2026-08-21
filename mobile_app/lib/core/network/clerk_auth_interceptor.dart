import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../security/storage_manager.dart';

/// Callback type for dynamically supplying the freshest Clerk session token.
typedef ClerkTokenProvider = Future<String?> Function();

/// Callback type for handling authentication expiration / unauthorized events.
typedef OnUnauthorizedCallback = void Function(DioException error);

/// Custom Dio Interceptor that automatically injects the active Clerk session JWT
/// into the `Authorization: Bearer <token>` header for all backend requests.
class ClerkAuthInterceptor extends QueuedInterceptor {
  final ClerkTokenProvider? tokenProvider;
  final OnUnauthorizedCallback? onUnauthorized;

  ClerkAuthInterceptor({
    this.tokenProvider,
    this.onUnauthorized,
  });

  /// Helper to asynchronously resolve the freshest available Clerk JWT token:
  /// 1. Calls [tokenProvider] if provided.
  /// 2. Falls back to secure local storage (`StorageManager.instance.getAuthToken()`).
  Future<String?> resolveClerkSessionToken() async {
    try {
      // 1. Injected dynamic provider
      if (tokenProvider != null) {
        final token = await tokenProvider!();
        if (token != null && token.isNotEmpty) {
          await StorageManager.instance.saveAuthToken(token);
          return token;
        }
      }

      // 2. Fallback to FlutterSecureStorage
      final cachedToken = await StorageManager.instance.getAuthToken();
      if (cachedToken != null && cachedToken.isNotEmpty) {
        return cachedToken;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ClerkAuthInterceptor] Error resolving Clerk token: $e');
      }
    }
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. If Authorization header is not manually provided, inject Clerk Bearer token
    if (!options.headers.containsKey('Authorization') ||
        options.headers['Authorization'] == null ||
        (options.headers['Authorization'] as String).isEmpty) {
      final token = await resolveClerkSessionToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    // 2. Inject standard headers
    options.headers['Accept'] = 'application/json';
    options.headers['X-Client-Platform'] = 'flutter';

    if (kDebugMode) {
      final hasAuth = options.headers.containsKey('Authorization');
      print('🚀 [DioRequest] ${options.method} ${options.uri} (Auth: ${hasAuth ? "Bearer ..." : "None"})');
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('✅ [DioResponse] [${response.statusCode}] ${response.requestOptions.path}');
    }
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (kDebugMode) {
      print('❌ [DioError] [$statusCode] ${err.requestOptions.path}: ${err.response?.data ?? err.message}');
    }

    // Handle 401 Unauthorized session expiration
    if (statusCode == 401) {
      if (kDebugMode) {
        print('🔒 [ClerkAuthInterceptor] Received 401 Unauthorized. Session expired.');
      }
      if (onUnauthorized != null) {
        onUnauthorized!(err);
      }
    }

    return handler.next(err);
  }
}
