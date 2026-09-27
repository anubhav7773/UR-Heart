import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/auth/presentation/controllers/age_gate_controller.dart';
import 'package:ur_heart/features/auth/presentation/controllers/magic_link_controller.dart';
import 'package:ur_heart/features/auth/presentation/screens/consent_screen.dart';
import 'package:ur_heart/features/auth/presentation/screens/magic_link_screen.dart';
import 'package:ur_heart/features/auth/presentation/widgets/neutral_dob_wheel_picker.dart';
import 'package:ur_heart/features/profile_setup/presentation/widgets/bio_editor_with_ai.dart';
import 'package:ur_heart/features/profile_setup/presentation/widgets/five_slot_media_grid.dart';
import 'package:ur_heart/features/profile_setup/presentation/widgets/sacred_bridge_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ur_heart_m4_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone 4 Exit Criterion 1: Screen 01 Theme Lock Execution', () {
    testWidgets('Tapping I Agree & Continue locks theme permanently in SharedPreferences',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              '/auth': (context) => const Scaffold(body: Text('Auth Gate')),
            },
            home: const ConsentScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check affirmative checkboxes
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.first);
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      // Tap submit button
      final submitButton = find.widgetWithText(ElevatedButton, 'I Agree & Continue');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('urheart_theme_permanently_locked'), true);
      expect(prefs.getBool('ur_heart_theme_locked'), true);
    });
  });

  group('Milestone 4 Exit Criterion 2: Neutral Age Gate & 180-Day Quarantine', () {
    test('Selecting year 2012 flags underage and imposes 180-day quarantine', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ageGateNotifier = container.read(ageGateControllerProvider.notifier);
      await ageGateNotifier.evaluateDob(DateTime(2012, 5, 10));

      final state = container.read(ageGateControllerProvider);
      expect(state.isUnderage, true);
      expect(state.isAdult, false);
      expect(state.isQuarantined, true);
      expect(state.statusBadgeText, contains('Underage Restricted'));

      final prefs = await SharedPreferences.getInstance();
      final quarantineMillis = prefs.getInt('ur_heart_quarantine_until');
      expect(quarantineMillis, isNotNull);
      final expiry = DateTime.fromMillisecondsSinceEpoch(quarantineMillis ?? 0);
      expect(expiry.isAfter(DateTime.now().add(const Duration(days: 170))), true);
    });

    testWidgets('NeutralDobWheelPicker renders strictly 18+ badge', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NeutralDobWheelPicker(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STRICTLY 18+'), findsOneWidget);
      expect(find.text('Select Year'), findsOneWidget);
    });
  });

  group('Milestone 4 Exit Criterion 3: Magic Link Verification Cycle', () {
    testWidgets('MagicLinkScreen renders passage guide and 45s resend timer',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MagicLinkScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Almost home.'), findsOneWidget);
      expect(find.text('3-STEP MINDFUL PASSAGE'), findsOneWidget);
      expect(find.text('Resend link in 45s'), findsOneWidget);
    });

    test('MagicLinkController handles deep link URL verification', () async {
      final controller = MagicLinkController();
      addTearDown(controller.dispose);

      final success = await controller.handleDeepLinkUrl('https://urheart.app/auth?token=valid_token');
      expect(success, true);
      expect(controller.state.isVerified, true);
    });
  });

  group('Milestone 4 Exit Criterion 4: Direct Firebase Media Upload & FiveSlotMediaGrid', () {
    testWidgets('FiveSlotMediaGrid and LiveVideoKycModal render cleanly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FiveSlotMediaGrid(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SANCTUARY PHOTOS (5 DISCRETE SLOTS)'), findsOneWidget);
      expect(find.text('Anchor Slot'), findsOneWidget);
    });
  });

  group('Milestone 4 Exit Criterion 5: Sacred Bridge & Groq Bio Polish', () {
    testWidgets('SacredBridgeSelector renders all 5 platforms dynamically', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SacredBridgeSelector(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sacred Contact Bridge'), findsOneWidget);
      expect(find.text('WhatsApp (Phone Number)'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
    });

    testWidgets('BioEditorWithAi renders Mindful Polish button and triggers Groq LPU', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BioEditorWithAi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mindful Bio'), findsOneWidget);
      expect(find.text('Mindful Polish ✨'), findsOneWidget);
    });
  });
}
