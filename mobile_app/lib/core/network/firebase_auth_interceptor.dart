import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../navigation/nav_keys.dart';
import '../security/storage_manager.dart';
import '../../features/auth/auth_screen.dart';

/// Dynamic token provider callback
typedef FirebaseTokenProvider = Future<String?> Function();

/// Callback invoked on 401 Unauthorized
typedef OnUnauthorizedCallback = void Function(DioException error);

/// Custom Dio Interceptor that automatically injects the active Firebase ID token
/// into the `Authorization: Bearer <token>` header for all outgoing API requests.
class FirebaseAuthInterceptor extends QueuedInterceptor {
  final FirebaseTokenProvider? tokenProvider;
  final OnUnauthorizedCallback? onUnauthorized;

  static bool _isHandling401 = false;

  FirebaseAuthInterceptor({
    this.tokenProvider,
    this.onUnauthorized,
  });

  /// Triggers a clean session purge and redirects user to AuthScreen
  static Future<void> handleSessionExpired() async {
    if (_isHandling401) return;
    _isHandling401 = true;
    try {
      if (kDebugMode) {
        print('🔒 [FirebaseAuthInterceptor] 401 Unauthorized detected. Purging session.');
      }
      await StorageManager.instance.clearAll();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      final navState = rootNavigatorKey.currentState;
      if (navState != null) {
        navState.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [FirebaseAuthInterceptor] Error during session purge: $e');
      }
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        _isHandling401 = false;
      });
    }
  }

  /// Resolves the freshest Firebase ID token:
  /// 1. Calls [tokenProvider] if explicitly provided.
  /// 2. Queries active `FirebaseAuth.instance.currentUser?.getIdToken()`.
  /// 3. Falls back to secure local cache in `StorageManager.instance.getAuthToken()`.
  Future<String?> resolveFirebaseToken({bool forceRefresh = false}) async {
    try {
      if (tokenProvider != null) {
        final token = await tokenProvider!();
        if (token != null && token.isNotEmpty) {
          await StorageManager.instance.saveAuthToken(token);
          return token;
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final token = await currentUser.getIdToken(forceRefresh);
        if (token != null && token.isNotEmpty) {
          await StorageManager.instance.saveAuthToken(token);
          await StorageManager.instance.saveUserId(currentUser.uid);
          return token;
        }
      }

      final cachedToken = await StorageManager.instance.getAuthToken();
      if (cachedToken != null && cachedToken.isNotEmpty) {
        return cachedToken;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [FirebaseAuthInterceptor] Error resolving Firebase token: $e');
      }
    }
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.extra['request_stopwatch'] = Stopwatch()..start();

    if (!options.headers.containsKey('Authorization') ||
        options.headers['Authorization'] == null ||
        (options.headers['Authorization'] as String).isEmpty) {
      final token = await resolveFirebaseToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    options.headers['Accept'] = 'application/json';
    options.headers['X-Client-Platform'] = 'flutter';

    if (kDebugMode) {
      final hasAuth = options.headers.containsKey('Authorization');
      print('🚀 [DioClient] ${options.method} ${options.uri} (Auth: ${hasAuth ? "Bearer [Firebase]" : "None"})');
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final stopwatch = response.requestOptions.extra['request_stopwatch'] as Stopwatch?;
    final elapsedMs = stopwatch != null ? '${stopwatch.elapsedMilliseconds}ms' : 'N/A';

    if (kDebugMode) {
      print('✅ [DioClient] [${response.statusCode}] ${response.requestOptions.path} ($elapsedMs)');
    }
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final stopwatch = err.requestOptions.extra['request_stopwatch'] as Stopwatch?;
    final elapsedMs = stopwatch != null ? '${stopwatch.elapsedMilliseconds}ms' : 'N/A';
    final statusCode = err.response?.statusCode;

    if (kDebugMode) {
      print('❌ [DioClient] [$statusCode] ${err.requestOptions.path} ($elapsedMs): ${err.response?.data ?? err.message}');
    }

    if (statusCode == 401) {
      if (kDebugMode) {
        print('🔒 [FirebaseAuthInterceptor] Received 401 Unauthorized. Session expired.');
      }
      if (onUnauthorized != null) {
        onUnauthorized!(err);
      }
      handleSessionExpired();
    }

    return handler.next(err);
  }
}
