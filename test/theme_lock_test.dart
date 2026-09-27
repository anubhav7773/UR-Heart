import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/constants/app_colors.dart';
import 'package:ur_heart/core/theme/theme_controller.dart';
import 'package:ur_heart/core/theme/widgets/permanent_theme_lock_dialog.dart';
import 'package:ur_heart/core/theme/widgets/theme_selector_pill.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 Exit Criterion 1: Default Light Installation Test', () {
    testWidgets('Fresh install boots into Light Sanctuary (#F9F7F2) by default',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify MaterialApp uses light theme and LightSanctuaryTokens background
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.scaffoldBackgroundColor,
          LightSanctuaryTokens.background);
      expect(materialApp.theme?.scaffoldBackgroundColor,
          const Color(0xFFF9F6F0));

      // Verify Header Pill displays 'Light Mode'
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.byType(ThemeSelectorPill), findsOneWidget);
    });

    test('ThemeController initializes with SanctuaryTheme.light and isLocked: false',
        () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();
      await controller.loadThemeFromPersistence();

      expect(controller.state.activeTheme, SanctuaryTheme.light);
      expect(controller.state.isLocked, false);
    });
  });

  group('Phase 3 Exit Criterion 2: One-Time Theme Lock Verification', () {
    testWidgets(
        'Tapping ThemeSelectorPill shows disclaimer dialog and Confirm & Lock switches theme permanently',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Unlocked Light Mode Pill
      expect(find.text('Light Mode'), findsOneWidget);

      // 2. Tap on Header Pill
      await tester.tap(find.byType(ThemeSelectorPill));
      await tester.pumpAndSettle();

      // 3. Verify Warning Dialog appears with explicit permanent disclaimer
      expect(find.byType(PermanentThemeLockDialog), findsOneWidget);
      expect(find.text('Permanent Visual Sanctuary'), findsOneWidget);
      expect(
        find.textContaining('UR-Heart enforces an unhurried, permanent visual mode'),
        findsOneWidget,
      );
      expect(find.text('Keep Current'), findsOneWidget);
      expect(find.text('Confirm & Lock'), findsOneWidget);

      // 4. Tap "Confirm & Lock"
      await tester.tap(find.text('Confirm & Lock'));
      await tester.pumpAndSettle();

      // 5. Verify Dialog is dismissed and theme switched to Dark Sanctuary
      expect(find.byType(PermanentThemeLockDialog), findsNothing);
      expect(find.text('Dark Sanctuary'), findsOneWidget);

      // 6. Verify MaterialApp switched to Dark theme
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.darkTheme?.scaffoldBackgroundColor,
          DarkSanctuaryTokens.background);
      expect(materialApp.darkTheme?.scaffoldBackgroundColor,
          const Color(0xFF0F1115));

      // 7. Verify Locked State: Tapping the static locked badge does NOT open dialog
      await tester.tap(find.byType(ThemeSelectorPill));
      await tester.pumpAndSettle();
      expect(find.byType(PermanentThemeLockDialog), findsNothing);

      // 8. Verify SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ur_heart_theme_mode'), 'dark');
      expect(prefs.getBool('ur_heart_theme_locked'), true);
    });

    testWidgets('Tapping "Keep Current" dismisses dialog without locking theme',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ThemeSelectorPill));
      await tester.pumpAndSettle();

      expect(find.byType(PermanentThemeLockDialog), findsOneWidget);

      await tester.tap(find.text('Keep Current'));
      await tester.pumpAndSettle();

      expect(find.byType(PermanentThemeLockDialog), findsNothing);
      expect(find.text('Light Mode'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ur_heart_theme_locked'), null);
    });
  });
}
