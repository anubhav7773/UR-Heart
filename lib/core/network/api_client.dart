import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
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
  return ApiClient();
});
