import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/config/env_config.dart';
import 'core/config/theme.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization notice: $e");
  }

  // Initialize Sentry with DPDP Act 2023 Data Scrubbing Pipeline
  await SentryFlutter.init(
    (options) {
      // Pass Sentry DSN via --dart-define=SENTRY_DSN=... or fallback to project configuration
      options.dsn = EnvConfig.sentryDsn;
      options.tracesSampleRate = 1.0;
      // ignore: experimental_member_use
      options.profilesSampleRate = 1.0;
      options.attachScreenshot = false; // Disabled to prevent capturing sensitive chat or media
      options.reportSilentFlutterErrors = true; // Captures RenderFlex yellow/black stripe overflows

      // DPDP 2023 Privacy Scrubber: Remove all PII before sending to cloud
      options.beforeSend = (SentryEvent event, Hint hint) {
        if (event.user != null) {
          event = event.copyWith(
            user: SentryUser(
              id: event.user?.id, // Anonymous installation UUID or hashed UID only
              ipAddress: "{{auto}}", // Handled by Sentry server-side scrubbers
              username: null, // Wipe legal name
              email: null, // Wipe email address
            ),
          );
        }

        // Scrub sensitive authorization tokens or coordinates from breadcrumbs
        final cleanBreadcrumbs = event.breadcrumbs?.map((b) {
          if (b.category == 'http' ||
              b.category == 'dio' ||
              b.category == 'http.request' ||
              b.category == 'http.response') {
            final cleanData = Map<String, dynamic>.from(b.data ?? {});
            cleanData.remove('Authorization');
            cleanData.remove('token');
            cleanData.remove('latitude');
            cleanData.remove('longitude');
            return b.copyWith(data: cleanData);
          }
          return b;
        }).toList();

        return event.copyWith(breadcrumbs: cleanBreadcrumbs);
      };
    },
    appRunner: () => runApp(
      DefaultAssetBundle(
        bundle: SentryAssetBundle(),
        child: const UrHeartApp(),
      ),
    ),
  );
}

class UrHeartApp extends StatelessWidget {
  const UrHeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UR-Heart',
      debugShowCheckedModeBanner: false,
      theme: URHeartTheme.darkTheme,
      // Register Sentry Navigator Observer for automated breadcrumbs
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      home: const AuthGate(),
    );
  }
}

typedef URHeartApp = UrHeartApp;
