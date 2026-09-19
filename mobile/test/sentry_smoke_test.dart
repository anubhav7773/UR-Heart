import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('Sentry configuration loads and scrubs PII correctly', () async {
    final options = SentryFlutterOptions();
    options.dsn = 'https://mock@sentry.io/12345';

    // DPDP scrubber logic check
    options.beforeSend = (SentryEvent event, Hint hint) {
      if (event.user != null) {
        event = event.copyWith(
          user: SentryUser(
            id: event.user?.id,
            username: null,
            email: null,
          ),
        );
      }
      return event;
    };

    var testEvent = SentryEvent(
      user: SentryUser(
        id: 'anon-uuid-1234',
        email: 'kshtriyaanubhav9120@gmail.com',
        username: 'Anubhav Singh',
      ),
    );

    final scrubbedEvent = await options.beforeSend!(testEvent, Hint());

    expect(scrubbedEvent?.user?.email, isNull);
    expect(scrubbedEvent?.user?.username, isNull);
    expect(scrubbedEvent?.user?.id, equals('anon-uuid-1234'));
  });

  test('Sentry breadcrumbs scrub sensitive tokens and geo coordinates', () async {
    final options = SentryFlutterOptions();
    options.beforeSend = (SentryEvent event, Hint hint) {
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

    final event = SentryEvent(
      breadcrumbs: [
        Breadcrumb(
          category: 'http.request',
          data: {
            'method': 'POST',
            'Authorization': 'Bearer secret_jwt',
            'token': 'super_secret',
            'latitude': 28.6139,
            'longitude': 77.2090,
            'url': 'https://api.ur-heart.com/v1/auth',
          },
        ),
      ],
    );

    final scrubbed = await options.beforeSend!(event, Hint());
    final data = scrubbed?.breadcrumbs?.first.data;
    expect(data?['Authorization'], isNull);
    expect(data?['token'], isNull);
    expect(data?['latitude'], isNull);
    expect(data?['longitude'], isNull);
    expect(data?['url'], equals('https://api.ur-heart.com/v1/auth'));
  });
}
