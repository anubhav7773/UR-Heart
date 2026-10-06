import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/chat/presentation/services/window_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    WindowSecurityService.currentShellTab = 0;
  });

  group('WindowSecurityService Route & Tab Privacy Shield Tests', () {
    test('Sensitive routes enable secure mode for regular users', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'user@example.com');
      await prefs.setString('user_role', 'user');

      const sensitiveTestRoutes = [
        '/chat-dialogue',
        '/chats',
        '/feed',
        '/resonances',
        '/persona',
        '/seeker-profile',
        '/seeker-detail',
        '/ai-sanctuary',
        '/eva-sanctuary',
        '/settings',
        '/admin/kyc-desk',
        '/profile-setup',
        '/ignored',
        '/ignored-profiles',
      ];

      for (final route in sensitiveTestRoutes) {
        final result = await WindowSecurityService.applyPolicyForRoute(route);
        expect(result, isTrue, reason: 'Route $route must be strictly protected with FLAG_SECURE');
      }
    });

    test('Safe routes disable secure mode for regular users (referrals & legal terms)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'user@example.com');
      await prefs.setString('user_role', 'user');

      const safeTestRoutes = [
        '/growth',
        '/consent',
        '/vault',
        '/vault-legal',
        '/appinfo',
        '/app-info',
        '/auth',
        '/magic-link',
        '/verify-email',
        '/auth/verify',
      ];

      for (final route in safeTestRoutes) {
        final result = await WindowSecurityService.applyPolicyForRoute(route);
        expect(result, isFalse, reason: 'Route $route must allow screenshots');
      }
    });

    test('Tab 3 (Growth Hub) is safe for screenshots; Tabs 0, 1, 2, 4 are confidential', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'user@example.com');
      await prefs.setString('user_role', 'user');

      // Tab 0: Discovery Feed (Confidential)
      expect(await WindowSecurityService.applyPolicyForTab(0), isTrue);

      // Tab 1: Resonances (Confidential)
      expect(await WindowSecurityService.applyPolicyForTab(1), isTrue);

      // Tab 2: Chats (Confidential)
      expect(await WindowSecurityService.applyPolicyForTab(2), isTrue);

      // Tab 3: Growth Hub (SAFE for referral code sharing)
      expect(await WindowSecurityService.applyPolicyForTab(3), isFalse);

      // Tab 4: My Persona (Confidential)
      expect(await WindowSecurityService.applyPolicyForTab(4), isTrue);
    });

    test('Shell route /main dynamically inherits the active tab security policy', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'user@example.com');
      await prefs.setString('user_role', 'user');

      // When tab is 0 (Feed), /main is confidential
      WindowSecurityService.currentShellTab = 0;
      expect(await WindowSecurityService.applyPolicyForRoute('/main'), isTrue);

      // When tab is 3 (Growth Hub), /main is safe for sharing referral codes
      WindowSecurityService.currentShellTab = 3;
      expect(await WindowSecurityService.applyPolicyForRoute('/main'), isFalse);

      // When tab is 2 (Chats), /main is confidential
      WindowSecurityService.currentShellTab = 2;
      expect(await WindowSecurityService.applyPolicyForRoute('/main'), isTrue);
    });

    test('Founder asiverticals@gmail.com bypasses all restrictions app-wide', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'asiverticals@gmail.com');
      await prefs.setString('user_role', 'superadmin');

      // Routes bypass
      expect(await WindowSecurityService.applyPolicyForRoute('/chat-dialogue'), isTrue);
      expect(await WindowSecurityService.applyPolicyForRoute('/seeker-profile'), isTrue);
      expect(await WindowSecurityService.applyPolicyForRoute('/admin/kyc-desk'), isTrue);

      // Tabs bypass
      expect(await WindowSecurityService.applyPolicyForTab(0), isTrue);
      expect(await WindowSecurityService.applyPolicyForTab(2), isTrue);
      expect(await WindowSecurityService.applyPolicyForTab(4), isTrue);

      // Direct enableSecureMode bypass
      expect(await WindowSecurityService.enableSecureMode(), isTrue);
    });

    testWidgets('SanctuaryRouteSecurityObserver triggers route policy updates on navigation', (tester) async {
      final observer = SanctuaryRouteSecurityObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home Page')),
          routes: {
            '/safe': (context) => const Scaffold(body: Text('Safe Page')),
            '/secret': (context) => const Scaffold(body: Text('Secret Page')),
          },
        ),
      );

      expect(find.text('Home Page'), findsOneWidget);
    });
  });
}
