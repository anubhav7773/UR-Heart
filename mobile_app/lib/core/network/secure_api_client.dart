import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'environment_config.dart';
import 'firebase_auth_interceptor.dart';

/// Secure API Client Service with automated Firebase token injection,
/// environment-aware base URLs, and timeout resilience.
class SecureApiClient {
  static final SecureApiClient instance = SecureApiClient._internal();
  factory SecureApiClient() => instance;

  late final Dio _dio;
  Dio get dio => _dio;

  String get baseUrl => _dio.options.baseUrl;

  SecureApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvironmentConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Platform': 'flutter',
        },
      ),
    );

    // 1. Attach Firebase Authentication Interceptor
    _dio.interceptors.add(
      FirebaseAuthInterceptor(
        onUnauthorized: (error) {
          if (kDebugMode) {
            print('⚠️ [SecureApiClient] Session unauthorized callback triggered.');
          }
        },
      ),
    );

    // 2. Attach dynamic Base URL Interceptor in case environment changes at runtime
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final targetBaseUrl = EnvironmentConfig.baseUrl;
          if (options.baseUrl != targetBaseUrl) {
            options.baseUrl = targetBaseUrl;
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Updates the Base URL dynamically (e.g. after environment switch)
  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }

  // ===========================================================================
  // Standard HTTP Request Helpers
  // ===========================================================================

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
