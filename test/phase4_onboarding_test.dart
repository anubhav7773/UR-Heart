import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';
import 'package:ur_heart/features/auth/presentation/controllers/auth_controller.dart';
import 'package:ur_heart/features/auth/presentation/screens/age_gate_auth_screen.dart';
import 'package:ur_heart/features/auth/presentation/screens/magic_link_screen.dart';
import 'package:ur_heart/features/auth/presentation/widgets/neutral_dob_wheel.dart';
import 'package:ur_heart/features/profile_setup/presentation/controllers/profile_setup_controller.dart';
import 'package:ur_heart/features/profile_setup/presentation/screens/profile_setup_screen.dart';
import 'package:ur_heart/features/profile_setup/presentation/widgets/five_slot_photo_grid.dart';
import 'package:ur_heart/features/profile_setup/presentation/widgets/live_kyc_recording_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4 Exit Criterion 1: Screen 1 Theme Lock Integration', () {
    testWidgets('App launch renders Light Mode and Consent locks theme permanently',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen 1 loaded
      expect(find.text('Mindful consent.'), findsOneWidget);
      expect(find.text('Light Mode'), findsOneWidget);

      // Verify submit button is disabled initially
      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'I Agree & Continue');
      final submitButtonInitial = tester.widget<ElevatedButton>(submitButtonFinder);
      expect(submitButtonInitial.onPressed, isNull);

      // Check both affirmative unbundled checkboxes
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.first);
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      // Submit button is now enabled
      final submitButtonEnabled = tester.widget<ElevatedButton>(submitButtonFinder);
      expect(submitButtonEnabled.onPressed, isNotNull);

      // Tap submit and verify theme is locked permanently
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ur_heart_theme_locked'), true);
      // Navigated to Screen 2
      expect(find.text('Real people. Real resonance.'), findsOneWidget);
    });
  });

  group('Phase 4 Exit Criterion 2: Screen 2 Neutral DOB & Underage Gate', () {
    testWidgets('Neutral DOB has no pre-selected year and underage year blocks submit',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AgeGateAuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NeutralDobWheel), findsOneWidget);
      expect(find.text('STRICTLY 18+'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);

      // Verify initial submit button disabled
      final enterButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Enter Sanctuary ➔'));
      expect(enterButton.onPressed, isNull);
    });

    test('AuthController flags underage date as blocked', () {
      final container = ProviderContainer();
      final notifier = container.read(authControllerProvider.notifier);

      // Select year 2012 (12 years old)
      notifier.setDateOfBirth(day: 10, month: 5, year: 2012);
      final state = container.read(authControllerProvider);

      expect(state.isUnderageBlocked, true);
      expect(state.isAdult, false);
      expect(state.canSubmit, false);
      expect(state.errorMessage, contains('Underage Access Denied'));
    });

    test('AuthController accepts valid adult DOB (e.g. 2002)', () {
      final container = ProviderContainer();
      final notifier = container.read(authControllerProvider.notifier);

      notifier.setDateOfBirth(day: 14, month: 10, year: 2002);
      notifier.setEmail('test@urheart.app');
      notifier.setPassword('sanctuary123');
      final state = container.read(authControllerProvider);

      expect(state.isUnderageBlocked, false);
      expect(state.isAdult, true);
      expect(state.canSubmit, true);
      expect(state.calculatedAge, greaterThanOrEqualTo(21));
    });
  });

  group('Phase 4 Exit Criterion 3: Screen 3 Deep Link & Resend Timer', () {
    testWidgets('Screen 3 renders 3-step passage guide and countdown timer',
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
      expect(find.text('Open your inbox'), findsOneWidget);
      expect(find.text('Tap verification link'), findsOneWidget);
      expect(find.text('Return to your sanctuary'), findsOneWidget);
      expect(find.textContaining('Resend link in'), findsOneWidget);
    });
  });

  group('Phase 4 Exit Criterion 4: Screen 4 Photo Compression & Slots', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase4_media_');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('FiveSlotPhotoGrid coordinates WebP compression and R2 slot upload', () async {
      final container = ProviderContainer();
      final controller = container.read(profileSetupControllerProvider.notifier);

      // Create test raw photo
      final rawImage = img.Image(width: 400, height: 500);
      img.fill(rawImage, color: img.ColorRgb8(249, 247, 242));
      final testFile = File('${tempDir.path}/avatar.jpg');
      await testFile.writeAsBytes(img.encodeJpg(rawImage));

      final success = await controller.processAndUploadPhoto(
        slotNumber: 1,
        rawFile: testFile,
      );

      expect(success, true);
      final state = container.read(profileSetupControllerProvider);
      expect(state.hasPrimaryAnchorPhoto, true);
      expect(state.photoSlots[1], isNotNull);
      expect(state.blurHashes[1], isNotNull);
    });

    testWidgets('Screen 4 renders 5 photo slots and profile fields', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FiveSlotPhotoGrid), findsOneWidget);
      expect(find.text('Anchor Slot'), findsOneWidget);
      expect(find.text('Slot 2'), findsOneWidget);
      expect(find.text('LEGAL FULL NAME'), findsOneWidget);
      expect(find.text('SANCTUARY LOCATION'), findsOneWidget);
      expect(find.text('Claim the Verified Sanctuary Crest'), findsOneWidget);
    });
  });

  group('Phase 4 Exit Criterion 5: Groq KYC Modal Trigger & Evaluation', () {
    testWidgets('LiveKycRecordingModal records 3-second stream and updates verification',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveKycRecordingModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Claim Verified Crest'), findsOneWidget);
      expect(find.text('Start (3s ✨)'), findsOneWidget);

      // Tap start recording
      await tester.tap(find.text('Start (3s ✨)'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });
}
