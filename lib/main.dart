import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/app/ur_heart_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Graceful fallback for environments without google-services.json
  }

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
        const ProviderScope(
          child: URHeartApp(),
        ),
      ),
    );
  } else {
    runApp(
      const ProviderScope(
        child: URHeartApp(),
      ),
    );
  }
}
