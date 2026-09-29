import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_session_storage.dart';
import 'api_interceptors.dart';

/// Configured Dio API Client with security interceptors and timeout protections
class ApiClient {
  final Dio dio;

  ApiClient({
    String? baseUrl,
    Future<String?> Function()? authTokenProvider,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiEndpoints.defaultBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(ApiInterceptors(authTokenProvider: authTokenProvider));
  }
}

/// Global Riverpod Provider for API Client
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    authTokenProvider: () async {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
      try {
        return await SecureSessionStorage.instance.getAuthToken();
      } catch (_) {}
      return null;
    },
  );
});
