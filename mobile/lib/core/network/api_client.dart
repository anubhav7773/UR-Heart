import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../security/installation_service.dart';

/// Creates configured Dio client with automated authentication and sandbox headers.
Dio createApiClient({
  String? baseUrl,
  VoidCallback? onUnauthorized,
  VoidCallback? onForbidden,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? EnvConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 90),
    sendTimeout: const Duration(seconds: 90),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // 1. Inject Android App Sandbox UUID
      try {
        final installUuid = await InstallationService.getOrCreateInstallationUuid();
        options.headers['X-Installation-UUID'] = installUuid;
      } catch (e) {
        debugPrint('Failed to retrieve installation UUID: $e');
      }

      // 2. Inject Firebase Bearer Token
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
    onError: (DioException error, handler) {
      if (error.response?.statusCode == 401) {
        onUnauthorized?.call();
      } else if (error.response?.statusCode == 403) {
        onForbidden?.call();
      }
      return handler.next(error);
    },
  ));

  return dio;
}
