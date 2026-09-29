import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../storage/secure_session_storage.dart';

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
        token = await SecureSessionStorage.instance.getAuthToken();
      } catch (_) {}
    }

    if (token != null && token.isNotEmpty) {
      options.headers[authorizationHeaderKey] = '$bearerPrefix$token';
    }
    return handler.next(options);
  }
}
