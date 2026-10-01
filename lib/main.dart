import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app/ur_heart_app.dart';
import 'core/services/activity_logger_service.dart';
import 'core/services/sanctuary_notification_service.dart';
import 'core/storage/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Graceful fallback for environments without google-services.json
  }

  // Initialize ultra-premium outside-the-app system tray push notifications
  try {
    await SanctuaryNotificationService.instance.initialize();
  } catch (_) {}

  // Pre-resolve initial route from session storage to prevent flashes on app relaunch
  String? resolvedInitialRoute;
  try {
    final prefs = await SharedPreferences.getInstance();
    final secureToken = await SecureSessionStorage.instance.getAuthToken();
    final fbUser = FirebaseAuth.instance.currentUser;
    final hasAuth = fbUser != null ||
                    (secureToken != null && secureToken.isNotEmpty) ||
                    (prefs.getString('ur_heart_auth_token')?.isNotEmpty ?? false) ||
                    (prefs.getString('auth_token')?.isNotEmpty ?? false);
    final isProfileSetupDone = (prefs.getBool('ur_heart_profile_setup_completed') ?? false) ||
                               (prefs.getBool('ur_heart_has_entered_sanctuary') ?? false);
    final isConsentGiven = (prefs.getBool('urheart_theme_permanently_locked') ?? false) ||
                           (prefs.getBool('ur_heart_theme_locked') ?? false) ||
                           (prefs.getBool('ur_heart_consent_given') ?? false);

    if (hasAuth && isProfileSetupDone) {
      resolvedInitialRoute = '/main';
    } else if (hasAuth && !isProfileSetupDone) {
      resolvedInitialRoute = '/profile-setup';
    } else if (isConsentGiven) {
      resolvedInitialRoute = '/auth';
    } else {
      resolvedInitialRoute = '/consent';
    }

  } catch (_) {}

  // Stream app initialization event to Render Live Logs
  ActivityLogger.logAppStartup();

  const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://6535a0577cdc513bca0276bec7ca55b6@o4511946639015936.ingest.us.sentry.io/4512159339642880',
  );

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.10; // 10% sampling to protect free quota
        options.sendDefaultPii = false; // DPDP Compliance
        options.attachScreenshot = false;
        options.beforeSend = (event, hint) {
          // Strip sensitive tokens, UUIDs, and payload data
          final request = event.request;
          if (request != null) {
            request.headers.remove('Authorization');
            request.headers.remove('X-Installation-UUID');
            request.headers.remove('Cookie');

            if (request.data != null) {
              event = event.copyWith(
                request: request.copyWith(
                  data: '[REDACTED_BY_DPDP_POLICY]',
                ),
              );
            }
          }

          if (event.user != null) {
            event = event.copyWith(
              user: event.user?.copyWith(
                ipAddress: null,
                email: null,
                username: null,
              ),
            );
          }
          return event;
        };
      },
      appRunner: () => runApp(
        ProviderScope(
          child: URHeartApp(initialRoute: resolvedInitialRoute),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        child: URHeartApp(initialRoute: resolvedInitialRoute),
      ),
    );
  }
}
