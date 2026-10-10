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

    final sanitizedDetails = _sanitizeDetails(details);

    // Fire and forget to Render so client UI is never blocked
    _sendTelemetry(
      category: category,
      action: action,
      screen: screen,
      details: sanitizedDetails,
      userId: uid,
      timestamp: timestamp,
    ).catchError((Object err) {
      debugPrint('[ActivityLogger] Telemetry send error: $err');
    });
  }

  static String _maskEmail(String value) {
    final parts = value.split('@');
    if (parts.length != 2) return '***';
    final local = parts[0];
    final keep = local.length < 2 ? local.length : 2;
    return '${local.substring(0, keep)}***@${parts[1]}';
  }

  static Map<String, dynamic> _sanitizeDetails(Map<String, dynamic>? rawDetails) {
    if (rawDetails == null) return {};
    final sanitized = Map<String, dynamic>.from(rawDetails);
    if (sanitized.containsKey('email')) {
      sanitized['email'] = _maskEmail(sanitized['email'].toString());
    }
    if (sanitized.containsKey('user_email')) {
      sanitized['user_email'] = _maskEmail(sanitized['user_email'].toString());
    }
    if (sanitized.containsKey('latitude') && sanitized['latitude'] is num) {
      sanitized['latitude'] = ((sanitized['latitude'] as num) * 100).round() / 100;
    }
    if (sanitized.containsKey('longitude') && sanitized['longitude'] is num) {
      sanitized['longitude'] = ((sanitized['longitude'] as num) * 100).round() / 100;
    }
    if (sanitized.containsKey('lat') && sanitized['lat'] is num) {
      sanitized['lat'] = ((sanitized['lat'] as num) * 100).round() / 100;
    }
    if (sanitized.containsKey('lon') && sanitized['lon'] is num) {
      sanitized['lon'] = ((sanitized['lon'] as num) * 100).round() / 100;
    }
    return sanitized;
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
    final consentGiven = (prefs.getBool('ur_heart_consent_given') ?? false) ||
                         (prefs.getBool('ur_heart_theme_locked') ?? false);
    if (!consentGiven) {
      // FE-VULN-09: Delay telemetry streaming until explicit statutory consent
      return;
    }

    final rawEmail = prefs.getString('ur_heart_user_email');
    final maskedEmail = (rawEmail != null && rawEmail.contains('@'))
        ? _maskEmail(rawEmail)
        : 'pseudonymous';
    final isSetupDone = prefs.getBool('ur_heart_profile_setup_completed') ?? false;

    await log(
      category: 'APP_LIFECYCLE',
      action: 'APP_LAUNCHED',
      details: {
        'user_identifier_masked': maskedEmail,
        'is_setup_completed': isSetupDone,
        'platform': defaultTargetPlatform.toString(),
      },
    );
  }
}

extension _IsoDateTime on DateTime {
  String isoformat() => toIso8601String();
}
