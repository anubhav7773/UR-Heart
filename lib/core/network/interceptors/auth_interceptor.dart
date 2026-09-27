import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  final Future<String?> Function()? authTokenProvider;

  AuthInterceptor({this.authTokenProvider});

  static const String authorizationHeaderKey = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
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
