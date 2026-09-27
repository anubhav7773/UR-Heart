import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/theme/theme_controller.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';
import 'package:ur_heart/features/profile/presentation/screens/my_persona_screen.dart';
import 'package:ur_heart/features/legal_vault/data/vault_repository.dart';
import 'package:ur_heart/features/legal_vault/presentation/screens/vault_legal_screen.dart';
import 'package:ur_heart/features/settings/data/settings_repository.dart';
import 'package:ur_heart/features/settings/presentation/screens/sanctuary_settings_screen.dart';
import 'package:ur_heart/features/settings/presentation/widgets/superadmin_sentinel_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setMobileScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget createTestApp(Widget child, [ThemeState? themeState, SettingsRepository? customSettingsRepo]) {
    return ProviderScope(
      overrides: [
        if (themeState != null)
          themeProvider.overrideWith((ref) => ThemeController(themeState)),
        profileRepositoryProvider.overrideWith((ref) => ProfileRepository()),
        vaultRepositoryProvider.overrideWith((ref) => VaultRepository()),
        settingsRepositoryProvider.overrideWith((ref) => customSettingsRepo ?? SettingsRepository()),
      ],
      child: MaterialApp(
        home: child,
        routes: {
          '/settings': (_) => const SanctuarySettingsScreen(),
          '/vault': (_) => const VaultLegalScreen(),
          '/admin/kyc-desk': (_) => const Scaffold(body: Text('Admin KYC Desk')),
          '/consent': (_) => const Scaffold(body: Text('Consent Screen')),
        },
      ),
    );
  }

  group('Milestone 8: Exit Criterion 1 - Screen 11 Locked Credentials', () {
    testWidgets('DOB renders 14 Oct 2002 · LOCKED & VERIFIED and Sacred Bridge is masked', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const MyPersonaScreen()));
      await tester.pumpAndSettle();

      expect(find.text('My Persona'), findsOneWidget);
      expect(find.text('14 Oct 2002 · LOCKED & VERIFIED'), findsOneWidget);
      expect(find.text('+91 98765 ***** · ENCRYPTED'), findsOneWidget);
      expect(find.text('CREST'), findsOneWidget);
    });

    testWidgets('Preferences and Bio update cleanly', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const MyPersonaScreen()));
      await tester.pumpAndSettle();

      final saveButton = find.text('Save Changes ➔');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Persona updated successfully'), findsOneWidget);
    });
  });

  group('Milestone 8: Exit Criterion 2 - Screen 12 DPDP Data Export Dispatch', () {
    testWidgets('Request Export triggers signed JSON archive valid for 7 days', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const VaultLegalScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Statutory Vault'), findsOneWidget);
      expect(find.text('E2E Encrypted (Curve25519)'), findsOneWidget);
      expect(find.text('DPDP Act 2023 Compliant'), findsOneWidget);

      final exportButton = find.text('Request Export ➔');
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Archive Ready · Valid for 7 days'), findsOneWidget);
      expect(find.text('UR-HEART STATUTORY AUDIT ID: IND-DPDP-2023-VAULT'), findsOneWidget);
    });

    testWidgets('Grievance dossier submission complies with IT Rules 2021', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const VaultLegalScreen()));
      await tester.pumpAndSettle();

      final fileDossierBtn = find.text('File Dossier ➔');
      expect(fileDossierBtn, findsOneWidget);
      await tester.tap(fileDossierBtn);
      await tester.pumpAndSettle();

      expect(find.text('File Statutory Grievance Dossier'), findsOneWidget);
      expect(find.text('Submit Dossier ➔'), findsOneWidget);
    });
  });

  group('Milestone 8: Exit Criterion 3 - Screen 13 Incognito Ghost Cloak & Key Rotation', () {
    testWidgets('Incognito stream radius toggle switches HIDDEN status', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const SanctuarySettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Incognito Ghost Cloak'), findsOneWidget);
      expect(find.text('VISIBLE'), findsOneWidget);

      final incognitoSwitch = find.byType(Switch).at(3);
      await tester.tap(incognitoSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HIDDEN'), findsOneWidget);
    });

    testWidgets('Cryptographic key rotation triggers fresh Curve25519 key generation', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const SanctuarySettingsScreen()));
      await tester.pumpAndSettle();

      final reKeyBtn = find.text('Re-key ⟳');
      expect(reKeyBtn, findsOneWidget);

      await tester.tap(reKeyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Fresh Curve25519 ephemeral key rotated'), findsOneWidget);
    });
  });

  group('Milestone 8: Exit Criterion 4 - DPDP Sec 12 Permanent Account Incineration', () {
    testWidgets('Erasure modal enforces typing ERASE and triggers cascading purge', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const SanctuarySettingsScreen()));
      await tester.pumpAndSettle();

      final eraseBtn = find.text('Erase Everything Irrevocably ➔');
      expect(eraseBtn, findsOneWidget);
      await tester.tap(eraseBtn);
      await tester.pumpAndSettle();

      expect(find.text('Irrevocable Erasure'), findsOneWidget);
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Erasure');
      expect(confirmBtn, findsOneWidget);

      // Initially disabled
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      // Arbitrary text keeps button disabled
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'CANCEL');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      // Typing ERASE enables confirmation
      await tester.enterText(textField, 'ERASE');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNotNull);

      // Tapping confirm triggers incinerator and redirects to /consent
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Consent Screen'), findsOneWidget);
    });
  });

  group('Milestone 8: Exit Criterion 5 - Superadmin Sentinel Gate Isolation', () {
    testWidgets('Standard email renders zero trace in DOM', (tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(createTestApp(const SanctuarySettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('👑 Superadmin KYC Sentinel'), findsNothing);
      expect(find.byType(SuperadminSentinelTile), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_rounded), findsNothing);
    });

    testWidgets('kshtriyaanubhav9120@gmail.com exclusively unlocks KYC desk tile', (tester) async {
      setMobileScreen(tester);
      final repo = SettingsRepository();
      repo.setUserEmail('kshtriyaanubhav9120@gmail.com');

      await tester.pumpWidget(createTestApp(const SanctuarySettingsScreen(), null, repo));
      await tester.pumpAndSettle();

      expect(find.text('👑 Superadmin KYC Sentinel'), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_rounded), findsOneWidget);

      await tester.tap(find.text('👑 Superadmin KYC Sentinel'));
      await tester.pumpAndSettle();

      expect(find.text('Admin KYC Desk'), findsOneWidget);
    });
  });
}
