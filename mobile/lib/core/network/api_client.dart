import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/env_config.dart';
import '../security/installation_service.dart';

/// Creates configured Dio client with automated authentication, sandbox headers,
/// and Sentry network telemetry interceptors without leaking sensitive auth tokens.
Dio createApiClient({
  String? baseUrl,
  VoidCallback? onUnauthorized,
  VoidCallback? onForbidden,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? EnvConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // 1. Auth and Installation Sandbox Interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final installUuid = await InstallationService.getOrCreateInstallationUuid();
          options.headers['X-Installation-UUID'] = installUuid;
        } catch (e) {
          debugPrint('Failed to retrieve installation UUID: $e');
        }

        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final idToken = await user.getIdToken();
            if (idToken != null) {
              options.headers['Authorization'] = 'Bearer $idToken';
            }
          }
        } catch (e) {
          debugPrint('Failed to retrieve Firebase ID token: $e');
        }

        return handler.next(options);
      },
    ),
  );

  // 2. Sentry Network Telemetry Interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Record sanitized breadcrumb
        Sentry.addBreadcrumb(
          Breadcrumb(
            category: 'http.request',
            type: 'http',
            message: '${options.method} ${options.path}',
            data: {
              'method': options.method,
              'url': options.uri.toString(),
            },
            level: SentryLevel.info,
          ),
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        Sentry.addBreadcrumb(
          Breadcrumb(
            category: 'http.response',
            type: 'http',
            message: '${response.requestOptions.method} ${response.requestOptions.path} -> ${response.statusCode}',
            data: {
              'status_code': response.statusCode,
            },
            level: SentryLevel.info,
          ),
        );
        handler.next(response);
      },
      onError: (DioException err, handler) {
        // Capture network failure event in Sentry
        Sentry.captureException(
          err,
          stackTrace: err.stackTrace,
          withScope: (scope) {
            scope.setTag('http.status_code', '${err.response?.statusCode ?? 'none'}');
            scope.setTag('http.method', err.requestOptions.method);
            scope.setContexts('request_info', {
              'url': err.requestOptions.uri.toString(),
              'error_type': err.type.toString(),
            });
          },
        );

        if (err.response?.statusCode == 401) {
          onUnauthorized?.call();
        } else if (err.response?.statusCode == 403) {
          onForbidden?.call();
        }

        handler.next(err);
      },
    ),
  );

  return dio;
}
