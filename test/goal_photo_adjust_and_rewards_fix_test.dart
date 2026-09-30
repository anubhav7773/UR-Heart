import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/profile/presentation/widgets/moments_media_grid.dart';
import 'package:ur_heart/features/profile/presentation/widgets/photo_adjuster_dialog.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/mindful_streak_card.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/resource_metrics_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Problem 1 & 2 Verification: Growth PRO Layout and Reward Counters', () {
    testWidgets('ResourceMetricsBar displays Profile Skips, Direct Msgs, and Social Reveals tokens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResourceMetricsBar(
              isDark: false,
              swipesRemaining: 25,
              directLetters: 1,
              revealTokens: 3,
              isAdFree: false,
            ),
          ),
        ),
      );

      // Verify Profile Skips counter
      expect(find.text('25'), findsOneWidget);
      expect(find.text('Profile Skips'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      // Verify Direct Msgs counter
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Direct Msgs'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);

      // Verify Social Reveals counter (Problem 2)
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Social Reveals'), findsOneWidget);
      expect(find.byIcon(Icons.key_rounded), findsOneWidget);

      // Verify Sovereign/Mindful Status Badge
      expect(find.text('Mindful'), findsOneWidget);
      expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    });

    testWidgets('ResourceMetricsBar displays infinity symbol for sovereign ad-free user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResourceMetricsBar(
              isDark: true,
              swipesRemaining: 999,
              directLetters: 5,
              revealTokens: 10,
              isAdFree: true,
            ),
          ),
        ),
      );

      expect(find.text('∞'), findsNWidgets(2)); // Swipes and reveals show ∞
      expect(find.text('Sovereign'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('MindfulStreakCard renders without pixel overflow on narrow screen (Problem 1)', (tester) async {
      // Simulate a compact mobile screen: 340 width
      tester.view.physicalSize = const Size(340 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testState = GrowthHubState(
        streakCount: 2,
        boostPoints: 2,
        secondsRemaining: 86400,
        revealTokensCount: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            growthHubControllerProvider.overrideWith(
              (ref) => GrowthHubController(testState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MindfulStreakCard(isDark: false),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Streak header is displayed
      expect(find.text('DAY 2 MINDFUL STREAK'), findsOneWidget);
      // Verify Boost Pill is displayed
      expect(find.text('+50% Boost'), findsOneWidget);
      // Verify no exceptions were thrown
      expect(tester.takeException(), isNull);
    });
  });

  group('Problem 3 Verification: Photo Adjuster & Framing for Persona', () {
    late File sampleImageFile;

    setUp(() async {
      final tempDir = Directory.systemTemp;
      sampleImageFile = File('${tempDir.path}/test_image_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Create a test 200x200 bitmap image using package:image
      final img.Image image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 100, 50));
      final jpgBytes = img.encodeJpg(image);
      await sampleImageFile.writeAsBytes(jpgBytes);
    });

    tearDown(() async {
      if (sampleImageFile.existsSync()) {
        try {
          sampleImageFile.deleteSync();
        } catch (_) {}
      }
    });

    testWidgets('SanctuaryPhotoAdjusterDialog renders tools, controls and slider', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 850 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SanctuaryPhotoAdjusterDialog(
              initialFile: sampleImageFile,
              isDark: true,
              isAvatar: false,
              targetAspectRatio: 1.0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog header & guidance
      expect(find.text('Adjust Moment Framing'), findsOneWidget);
      expect(find.text('Drag & pinch so your face is clear and centered'), findsOneWidget);

      // Verify tools: Rotate, Reset, Grid Toggle
      expect(find.text('Rotate'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Grid On'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply & Save'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Toggle grid
      await tester.ensureVisible(find.text('Grid On'));
      await tester.tap(find.text('Grid On'));
      await tester.pumpAndSettle();
      expect(find.text('Grid Off'), findsOneWidget);

      // Rotate clockwise
      await tester.ensureVisible(find.text('Rotate'));
      await tester.tap(find.text('Rotate'));
      await tester.pumpAndSettle();

      // Reset
      await tester.ensureVisible(find.text('Reset'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
    });

    testWidgets('SanctuaryPhotoAdjusterDialog crop execution outputs valid cropped image on Apply & Save', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 850 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      File? resultFile;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  resultFile = await SanctuaryPhotoAdjusterDialog.show(
                    context,
                    file: sampleImageFile,
                    isDark: false,
                    isAvatar: false,
                    targetAspectRatio: 1.0,
                  );
                },
                child: const Text('Open Adjuster'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Adjuster'));
      await tester.pumpAndSettle();

      expect(find.text('Adjust Moment Framing'), findsOneWidget);

      // Tap Apply & Save within runAsync for real filesystem I/O
      await tester.ensureVisible(find.text('Apply & Save'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Apply & Save'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      // Verify result file was created, exists, and contains valid decoded image
      expect(resultFile, isNotNull);
      expect(resultFile!.existsSync(), isTrue);
      final bytes = resultFile!.readAsBytesSync();
      expect(bytes.length, greaterThan(0));
      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));

      // Cleanup
      try {
        resultFile!.deleteSync();
      } catch (_) {}
    });

    testWidgets('MomentsMediaGrid has square 1.0 aspect ratio to prevent clipping faces', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MomentsMediaGrid(
                photos: [sampleImageFile.path],
                isDark: false,
                onReplaceSlot: (_) {},
              ),
            ),
          ),
        ),
      );

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final GridView grid = tester.widget(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.childAspectRatio, 1.0);
    });
  });
}
