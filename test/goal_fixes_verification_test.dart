import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';
import 'package:ur_heart/features/auth/presentation/screens/consent_screen.dart';
import 'package:ur_heart/features/auth/presentation/screens/age_gate_auth_screen.dart';
import 'package:ur_heart/features/profile_setup/presentation/screens/profile_setup_screen.dart';
import 'package:ur_heart/features/navigation/presentation/screens/sanctuary_navigation_shell.dart';
import 'package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/sacred_kinship_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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
      expect(args.hasWaKey, true);
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
}
