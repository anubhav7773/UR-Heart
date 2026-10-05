import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/navigation/presentation/widgets/whatsapp_notification_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Goal Problem 1: Ultra-Premium WhatsApp-Style Notification Banner', () {
    testWidgets('Renders WhatsApp-style message notification correctly', (tester) async {
      bool tapped = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                WhatsAppNotificationBanner(
                  title: 'Aarav Sharma',
                  message: 'Hey, I felt a deep alignment with your reflections on literature.',
                  type: 'message',
                  isDark: true,
                  onTap: () {
                    tapped = true;
                  },
                  onDismiss: () {
                    dismissed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Settle the entrance slide animation
      await tester.pumpAndSettle();

      // Verify title, message, and WhatsApp "now" timestamp
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(
        find.text('Hey, I felt a deep alignment with your reflections on literature.'),
        findsOneWidget,
      );
      expect(dismissed, isFalse);
      expect(find.text('now'), findsOneWidget);

      // Verify WhatsApp green message badge icon is present
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      // Verify forward arrow action pill is present
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);

      // Tap on the notification banner
      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('Renders Resonance / Like notification with coral badge and dismisses on swipe up', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                WhatsAppNotificationBanner(
                  title: 'New Resonance',
                  message: 'Ananya resonated with your Core Values.',
                  type: 'like',
                  isDark: false,
                  onTap: () {},
                  onDismiss: () {
                    dismissed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify like badge
      expect(find.text('New Resonance'), findsOneWidget);
      expect(find.text('Ananya resonated with your Core Values.'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Drag up to dismiss
      await tester.drag(find.text('New Resonance'), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });

  group('Goal Problem 2: Launcher Icon Production Assets Verification', () {
    test('Launcher icon assets exist and are configured for production', () {
      // 1. Check colors.xml has #FFFFFF
      final colorsXml = File('android/app/src/main/res/values/colors.xml');
      expect(colorsXml.existsSync(), isTrue);
      final colorsContent = colorsXml.readAsStringSync();
      expect(colorsContent.contains('#FFFFFF'), isTrue);

      // 2. Check AndroidManifest has roundIcon configured
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue);
      final manifestContent = manifest.readAsStringSync();
      expect(manifestContent.contains('android:icon="@mipmap/ic_launcher"'), isTrue);
      expect(manifestContent.contains('android:roundIcon="@mipmap/ic_launcher_round"'), isTrue);

      // 3. Check adaptive mipmap XML definitions
      final icLauncherXml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(icLauncherXml.existsSync(), isTrue);
      final icRoundXml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml');
      expect(icRoundXml.existsSync(), isTrue);

      // 4. Check all mipmap densities have ic_launcher.png and ic_launcher_round.png
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final d in densities) {
        final launcherPng = File('android/app/src/main/res/mipmap-$d/ic_launcher.png');
        expect(launcherPng.existsSync(), isTrue, reason: 'Missing mipmap-$d/ic_launcher.png');
        expect(launcherPng.lengthSync(), greaterThan(100));

        final roundPng = File('android/app/src/main/res/mipmap-$d/ic_launcher_round.png');
        expect(roundPng.existsSync(), isTrue, reason: 'Missing mipmap-$d/ic_launcher_round.png');
        expect(roundPng.lengthSync(), greaterThan(100));

        final fgPng = File('android/app/src/main/res/drawable-$d/ic_launcher_foreground.png');
        expect(fgPng.existsSync(), isTrue, reason: 'Missing drawable-$d/ic_launcher_foreground.png');
        expect(fgPng.lengthSync(), greaterThan(100));
      }

      // 5. Check master assets
      expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
      expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
    });

    test('keep.xml protects notification drawables and colors from R8 shrinking', () {
      final keepFile = File('android/app/src/main/res/raw/keep.xml');
      expect(keepFile.existsSync(), isTrue);
      final content = keepFile.readAsStringSync();
      expect(content.contains('@drawable/ic_stat_urheart'), isTrue);
      expect(content.contains('@color/sacred_pine'), isTrue);
    });

    test('MainActivity.kt registers native notification channels with Android OS', () {
      final mainActivity = File('android/app/src/main/kotlin/com/urheart/app/MainActivity.kt');
      expect(mainActivity.existsSync(), isTrue);
      final content = mainActivity.readAsStringSync();
      expect(content.contains('createNotificationChannels()'), isTrue);
      expect(content.contains('ur_heart_sacred_dialogue'), isTrue);
      expect(content.contains('ur_heart_presence_channel'), isTrue);
      expect(content.contains('NotificationManager.IMPORTANCE_HIGH'), isTrue);
    });
  });
}

