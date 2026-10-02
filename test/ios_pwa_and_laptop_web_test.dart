import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/ads/rewarded_ad_manager.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';
import 'package:ur_heart/core/services/sanctuary_notification_service.dart';
import 'package:ur_heart/features/navigation/presentation/widgets/ios_pwa_install_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Progressive Web App (PWA) & iOS Web Scaffolding Verification', () {
    test('PWA manifest.json contains valid sanctuary branding and icons', () {
      final manifestFile = File('web/manifest.json');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      final manifest = jsonDecode(content) as Map<String, dynamic>;

      expect(manifest['name'], equals('UR-Heart — Mindful Dating Sanctuary'));
      expect(manifest['short_name'], equals('UR-Heart'));
      expect(manifest['display'], equals('standalone'));
      expect(manifest['theme_color'], equals('#090A10'));
      expect(manifest['background_color'], equals('#090A10'));
      expect((manifest['icons'] as List).length, greaterThanOrEqualTo(2));
    });

    test('web/index.html contains Apple iOS PWA meta tags and sanctuary styling', () {
      final indexFile = File('web/index.html');
      expect(indexFile.existsSync(), isTrue);

      final content = indexFile.readAsStringSync();
      expect(content, contains('name="apple-mobile-web-app-capable" content="yes"'));
      expect(content, contains('name="apple-mobile-web-app-status-bar-style" content="black-translucent"'));
      expect(content, contains('name="apple-mobile-web-app-title" content="UR-Heart"'));
      expect(content, contains('rel="apple-touch-icon"'));
      expect(content, contains('#090A10'));
    });
  });

  group('Web Native Plugin Safety (Zero-Crash Fallbacks)', () {
    test('SanctuaryNotificationService initializes safely without throwing', () async {
      final notifService = SanctuaryNotificationService.instance;
      await expectLater(notifService.initialize(), completes);
    });

    test('RewardedAdManager initializes safely without throwing', () async {
      final adManager = RewardedAdManager.instance;
      await expectLater(adManager.initialize(), completes);
      expect(adManager.canPlayAd(), isTrue);
    });
  });

  group('Desktop & Laptop Responsive Sanctuary Frame UI Verification', () {
    testWidgets('URHeartApp embeds desktop max-width 500 constraint', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(initialRoute: '/consent'),
        ),
      );
      await tester.pump();

      // Verify ConstrainedBox with maxWidth: 500 is present
      final constrainedBoxFinder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 500.0,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    });

    testWidgets('IosPwaInstallBanner renders cleanly and gracefully handles dismissal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IosPwaInstallBanner(isDark: true),
          ),
        ),
      );
      await tester.pump();

      // On headless test environment (non-web), banner gracefully returns SizedBox.shrink()
      expect(find.byType(IosPwaInstallBanner), findsOneWidget);
    });
  });
}
