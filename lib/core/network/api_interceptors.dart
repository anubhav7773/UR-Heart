import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/installation_service.dart';

/// Interceptor that injects X-Installation-UUID header on every request
/// and attaches Bearer authorization token when available
class ApiInterceptors extends Interceptor {
  final Future<String?> Function()? authTokenProvider;

  ApiInterceptors({this.authTokenProvider});

  static const String installationHeaderKey = 'X-Installation-UUID';
  static const String authorizationHeaderKey = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Inject app-scoped sandbox installation UUID
    final installationUuid = await InstallationService.getInstallationUuid();
    options.headers[installationHeaderKey] = installationUuid;

    // 2. Inject JWT Bearer token if session exists
    String? token;
    if (authTokenProvider != null) {
      try {
        token = await authTokenProvider!();
      } catch (_) {}
    }

    if (token == null || token.isEmpty) {
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}
    }

    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('ur_heart_auth_token');
      } catch (_) {}
    }

    if (token != null && token.isNotEmpty) {
      options.headers[authorizationHeaderKey] = '$bearerPrefix$token';
    }

    return handler.next(options);
  }
}
