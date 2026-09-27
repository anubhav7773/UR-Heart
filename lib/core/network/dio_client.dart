import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import 'interceptors/installation_interceptor.dart';
import 'interceptors/auth_interceptor.dart';

class DioClient {
  final Dio dio;

  DioClient({
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
    dio.interceptors.addAll([
      InstallationInterceptor(),
      AuthInterceptor(authTokenProvider: authTokenProvider),
    ]);
  }
}

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});
