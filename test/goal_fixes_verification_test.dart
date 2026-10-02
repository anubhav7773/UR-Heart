import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';
import 'package:ur_heart/features/auth/presentation/screens/consent_screen.dart';
import 'package:ur_heart/features/auth/presentation/screens/age_gate_auth_screen.dart';
import 'package:ur_heart/features/navigation/presentation/screens/sanctuary_navigation_shell.dart';
import 'package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/sacred_kinship_card.dart';
import 'package:ur_heart/features/auth/presentation/widgets/magic_link_passage_card.dart';
import 'package:ur_heart/core/constants/api_endpoints.dart';
import 'package:ur_heart/features/settings/presentation/widgets/official_web_sanctuary_card.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/sovereign_store_tab_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Problem 2 Verification: Session Persistence & Startup Routing', () {
    testWidgets('Cold start with completed profile routes directly to /main', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ur_heart_auth_token': 'jwt_session_token_xyz',
        'ur_heart_profile_setup_completed': true,
      });

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Launch URHeartApp with resolved route
      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(initialRoute: SanctuaryNavigationShell.routeName),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify SanctuaryNavigationShell is rendered immediately, ConsentScreen is never shown
      expect(find.byType(SanctuaryNavigationShell), findsOneWidget);
      expect(find.byType(ConsentScreen), findsNothing);

      // Clean up widget tree to dispose shell and cancel background polling timer
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('SanctuaryAppGateway dynamically redirects to /main when auth & profile exist', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ur_heart_auth_token': 'jwt_session_token_xyz',
        'ur_heart_profile_setup_completed': true,
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SanctuaryAppGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SanctuaryNavigationShell), findsOneWidget);

      // Clean up widget tree to dispose shell and cancel background polling timer
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('SanctuaryAppGateway dynamically redirects to /auth when consent given but not logged in', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ur_heart_consent_given': true,
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SanctuaryAppGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AgeGateAuthScreen), findsOneWidget);
    });
  });

  group('Problem 1 Verification: Notification Direct Routing Arguments', () {
    test('ChatDialogueArguments supports optional defaults for direct notification jumps', () {
      const args = ChatDialogueArguments(
        matchId: 'match-uuid-123',
        recipientId: 'user-uuid-456',
        recipientName: 'Aarav Sharma',
      );

      expect(args.matchId, 'match-uuid-123');
      expect(args.recipientId, 'user-uuid-456');
      expect(args.recipientName, 'Aarav Sharma');
      expect(args.recipientAge, 25);
      expect(args.isOnline, true);
      expect(args.hasWaKey, false);
    });
  });

  group('Problem 3 Verification: Multi-Platform Sharing & Real Referral System', () {
    testWidgets('SacredKinshipCard displays real referral code and multi-channel share buttons', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_referral_code': 'UR-HERO99',
      });

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SacredKinshipCard(
                referralCode: 'UR-HERO99',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check real referral code display
      expect(find.text('UR-HERO99'), findsOneWidget);
      expect(find.text('Sacred Kinship Referral'), findsOneWidget);

      // Check all 5 social share buttons
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.text('X (Twitter)'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Check primary share sheet button
      expect(find.text('Share Invitation Everywhere ➔'), findsOneWidget);

      // Check redeem section toggle
      expect(find.text('Have a referral code? Enter here ▼'), findsOneWidget);
    });
  });

  group('Magic Link Overhaul: Passkey-Free Live Step Tracker Verification', () {
    testWidgets('MagicLinkPassageCard displays 3 live steps, live listening status, and email client CTA', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MagicLinkPassageCard(
                currentStep: 2,
                elapsedSeconds: 15,
                targetEmail: 'seeker@urheart.app',
                onOpenEmailApp: () {},
                onOpenDirectLink: () {},
                onCopyLink: () {},
                onResend: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Live step tracker header and step counter
      expect(find.text('LIVE STEP TRACKER'), findsOneWidget);
      expect(find.text('Step 2 of 3'), findsOneWidget);

      // 2. Step 1: Dispatched
      expect(find.text('Sacred Link Dispatched'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);

      // 3. Step 2: Live Listening with formatted elapsed time and clean disclaimer
      expect(find.text('Open Email & Tap Sacred Link'), findsOneWidget);
      expect(find.text('Listening: 00:15'), findsOneWidget);
      expect(find.text('Email Verification Required'), findsOneWidget);

      // Verify dummy buttons are 100% REMOVED as requested
      expect(find.text('Open Email App Now ➔'), findsNothing);
      expect(find.text('Open Link in Browser Directly ➔'), findsNothing);
      expect(find.text('Copy Verification Link'), findsNothing);

      // 4. Step 3: Enter Profile Sanctuary
      expect(find.text('Enter Profile Sanctuary'), findsOneWidget);

      // 5. Verify passkey input fields are 100% ABSENT
      expect(find.text('Mindful 6-Digit Passkey'), findsNothing);
      expect(find.text('Passkey:'), findsNothing);
      expect(find.text('Verify Passkey & Enter ➔'), findsNothing);
    });
  });

  group('Official Domain Verification: urheart.asiverticals.me', () {
    test('ApiEndpoints configured with urheart.asiverticals.me', () {
      expect(ApiEndpoints.officialDomain, 'urheart.asiverticals.me');
      expect(ApiEndpoints.defaultBaseUrl, 'https://urheart.asiverticals.me');
      expect(ApiEndpoints.webSanctuaryUrl, 'https://urheart.asiverticals.me/appinfo');
    });

    testWidgets('OfficialWebSanctuaryCard renders official domain and launch button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfficialWebSanctuaryCard(isDark: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Official Web Sanctuary'), findsOneWidget);
      expect(find.text('urheart.asiverticals.me'), findsOneWidget);
      expect(find.text('Visit urheart.asiverticals.me'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_browser_rounded), findsOneWidget);
    });

    testWidgets('SovereignStoreTabView opens Sovereign Access Gateway modal with Web Store option', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SovereignStoreTabView(isDark: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify store banner and passes rendered
      expect(find.text('Sanctuary Web Store (10% Extra Passes)'), findsOneWidget);
      expect(find.text('1-Month Sovereign Pass'), findsOneWidget);

      // Tap first Unlock button
      final unlockBtn = find.text('Unlock').first;
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      // Verify Sovereign Access Gateway modal bottom sheet rendered
      expect(find.text('Sovereign Access Gateway'), findsOneWidget);
      expect(find.text('Web Sanctuary Store'), findsOneWidget);
      expect(find.text('+10% BONUS'), findsOneWidget);
      expect(find.text('Google Play In-App Billing'), findsOneWidget);
    });
  });
}


