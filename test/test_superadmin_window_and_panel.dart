import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/storage/secure_session_storage.dart';
import 'package:ur_heart/features/chat/presentation/services/window_security_service.dart';
import 'package:ur_heart/features/settings/data/settings_repository.dart';
import 'package:ur_heart/features/settings/presentation/widgets/superadmin_sentinel_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('WindowSecurityService Screen Recording Bypass Tests', () {
    test('isBypassedUser returns true when email is asiverticals@gmail.com', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'asiverticals@gmail.com');
      await prefs.setString('user_role', 'superadmin');

      final isBypassed = await WindowSecurityService.isBypassedUser();
      expect(isBypassed, isTrue);
    });

    test('isBypassedUser returns true when role is superadmin in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'superadmin');

      final isBypassed = await WindowSecurityService.isBypassedUser();
      expect(isBypassed, isTrue);
    });

    test('isBypassedUser returns false for regular user', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'seeker@urheart.app');
      await prefs.setString('user_role', 'user');

      final isBypassed = await WindowSecurityService.isBypassedUser();
      expect(isBypassed, isFalse);
    });

    test('enableSecureMode successfully bypasses FLAG_SECURE for asiverticals@gmail.com', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'asiverticals@gmail.com');
      await prefs.setString('user_role', 'superadmin');

      final result = await WindowSecurityService.enableSecureMode();
      expect(result, isTrue);
    });
  });

  group('SuperadminSentinelTile Widget Tests', () {
    testWidgets('Renders golden Sovereign Sentinel Desk when userRole is superadmin', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperadminSentinelTile(
              userRole: 'superadmin',
              isDark: true,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('SOVEREIGN SENTINEL DESK'), findsOneWidget);
      expect(find.text('Open KYC Escalation Desk ➔'), findsOneWidget);

      await tester.tap(find.text('Open KYC Escalation Desk ➔'));
      expect(tapped, isTrue);
    });

    testWidgets('Hides desk and renders SizedBox.shrink when userRole is regular user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SuperadminSentinelTile(
              userRole: 'user',
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('SOVEREIGN SENTINEL DESK'), findsNothing);
      expect(find.text('Open KYC Escalation Desk ➔'), findsNothing);
    });
  });

  group('SettingsRepository & SecureSessionStorage Role Integration', () {
    test('saveUserSession persists superadmin role in SharedPreferences for asiverticals', () async {
      await SecureSessionStorage.instance.saveUserSession(
        userId: 'usr_test_123',
        email: 'asiverticals@gmail.com',
        role: 'user', // should be auto-elevated by saveUserSession
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_role'), 'superadmin');
      expect(prefs.getString('ur_heart_user_email'), 'asiverticals@gmail.com');
    });

    test('fetchSettings returns superadmin role when asiverticals is cached', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_user_email', 'asiverticals@gmail.com');
      await prefs.setString('user_role', 'superadmin');

      final repo = SettingsRepository();
      final settings = await repo.fetchSettings();

      expect(settings.userRole, 'superadmin');
      expect(settings.userEmail, 'asiverticals@gmail.com');
    });
  });
}
