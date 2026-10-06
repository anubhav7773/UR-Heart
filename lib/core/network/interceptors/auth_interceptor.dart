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

    // SharedPreferences fallback for rapid post-login transitions
    SharedPreferences? prefs;
    if (token == null || token.isEmpty) {
      try {
        prefs = await SharedPreferences.getInstance();
        token = prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token');
      } catch (_) {}
    }

    if (token != null && token.isNotEmpty) {
      options.headers[authorizationHeaderKey] = '$bearerPrefix$token';
    }

    // Attach caller identity headers for defense-in-depth self-exclusion
    try {
      prefs ??= await SharedPreferences.getInstance();
      final uid = prefs.getString('ur_heart_user_id') ?? prefs.getString('profile_user_id');
      final email = prefs.getString('ur_heart_user_email');
      if (uid != null && uid.isNotEmpty) {
        options.headers['X-User-Id'] = uid;
      }
      if (email != null && email.isNotEmpty) {
        options.headers['X-User-Email'] = email;
      }
    } catch (_) {}

    return handler.next(options);
  }
}
