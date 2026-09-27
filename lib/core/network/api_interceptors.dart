import 'package:dio/dio.dart';
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
    final tokenProvider = authTokenProvider;
    if (tokenProvider != null) {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        options.headers[authorizationHeaderKey] = '$bearerPrefix$token';
      }
    }

    return handler.next(options);
  }
}
