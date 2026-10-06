import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry Observability Service with strict DPDP Act 2023 PII Sanitization
class SentryService {
  SentryService._();

  static const double tracesSampleRate = 0.10; // 10% sampling to conserve free tier quota
  static const String defaultDsn =
      'https://6535a0577cdc513bca0276bec7ca55b6@o4511946639015936.ingest.us.sentry.io/4512159339642880';

  static Future<void> initialize({
    required AppRunner appRunner,
    String? dsn,
  }) async {
    final effectiveDsn = dsn ??
        const String.fromEnvironment('SENTRY_DSN', defaultValue: defaultDsn);

    if (effectiveDsn.isEmpty) {
      // Local/Test mode without external Sentry connection
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = effectiveDsn;
        options.tracesSampleRate = tracesSampleRate;
        options.sendDefaultPii = false; // Strictly disabled under DPDP
        options.attachScreenshot = false;

        options.beforeSend = (event, hint) {
          // 1. Strip sensitive headers and authentication secrets
          final request = event.request;
          if (request != null) {
            request.headers.remove('Authorization');
            request.headers.remove('X-Installation-UUID');
            request.headers.remove('Cookie');

            // 2. Redact sensitive payload body
            if (request.data != null) {
              event = event.copyWith(
                request: request.copyWith(
                  data: '[REDACTED_BY_DPDP_POLICY]',
                ),
              );
            }
          }

          // 3. Scrub user IP addresses and credentials
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
      appRunner: appRunner,
    );
  }

  /// Dispatches user-reported issues or suggestions to Sentry's issue tracker
  static Future<void> captureUserFeedback({
    required String category,
    required String description,
    Map<String, dynamic>? diagnostics,
  }) async {
    try {
      await Sentry.captureMessage(
        '[$category] $description',
        level: category == 'bug_report' ? SentryLevel.warning : SentryLevel.info,
        withScope: (scope) {
          scope.setTag('feedback_category', category);
          if (diagnostics != null) {
            for (final entry in diagnostics.entries) {
              scope.setExtra(entry.key, entry.value);
            }
          }
        },
      );
    } catch (_) {}
  }
}
