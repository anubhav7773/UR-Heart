import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';

/// Production-grade Live Activity Logger streaming real-time events to Render
class ActivityLogger {
  const ActivityLogger._();

  static String? _cachedUserId;

  static void setUserId(String userId) {
    _cachedUserId = userId;
  }

  /// Sends a structured activity log to the Render backend live stream
  static Future<void> log({
    required String category,
    required String action,
    String? screen,
    Map<String, dynamic>? details,
    String? userId,
  }) async {
    final timestamp = DateTime.now().toUtc().isoformat();
    final uid = userId ?? _cachedUserId ?? 'anonymous';

    debugPrint('[ActivityLogger] [$category] $action | Screen: $screen | User: $uid');

    // Fire and forget to Render so client UI is never blocked
    _sendTelemetry(
      category: category,
      action: action,
      screen: screen,
      details: details,
      userId: uid,
      timestamp: timestamp,
    ).catchError((Object err) {
      debugPrint('[ActivityLogger] Telemetry send error: $err');
    });
  }

  static Future<void> _sendTelemetry({
    required String category,
    required String action,
    String? screen,
    Map<String, dynamic>? details,
    required String userId,
    required String timestamp,
  }) async {
    try {
      final url = Uri.parse('${ApiEndpoints.defaultBaseUrl}${ApiEndpoints.telemetryActivity}');
      final body = jsonEncode({
        'category': category,
        'action': action,
        'user_id': userId,
        'screen': screen,
        'details': details ?? {},
        'timestamp': timestamp,
      });

      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Graceful offline degradation
    }
  }

  /// Helper to record app startup
  static Future<void> logAppStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('ur_heart_user_email') ?? 'unauthenticated';
    final isSetupDone = prefs.getBool('ur_heart_profile_setup_completed') ?? false;

    await log(
      category: 'APP_LIFECYCLE',
      action: 'APP_LAUNCHED',
      details: {
        'user_email': email,
        'is_setup_completed': isSetupDone,
        'platform': defaultTargetPlatform.toString(),
      },
    );
  }
}

extension _IsoDateTime on DateTime {
  String isoformat() => toIso8601String();
}
