import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/constants/api_endpoints.dart';
import 'package:ur_heart/features/auth/presentation/widgets/statutory_links_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Statutory Legal & Web Sanctuary Consent Links Audit', () {
    test('Check 1: Statutory URL Endpoints match exact official specifications', () {
      expect(ApiEndpoints.officialDomain, 'urheart.asiverticals.me');
      expect(ApiEndpoints.termsOfServiceUrl, 'https://urheart.asiverticals.me/terms');
      expect(ApiEndpoints.privacyPolicyUrl, 'https://urheart.asiverticals.me/privacy');
      expect(ApiEndpoints.webSanctuaryUrl, 'https://urheart.asiverticals.me/appinfo');
      expect(ApiEndpoints.deleteAccountUrl, 'https://urheart.asiverticals.me/delete-account');
    });

    testWidgets('Check 2: StatutoryLinksCard displays all 4 statutory portals including Web Sanctuary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatutoryLinksCard(isDark: true),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Headers & Titles
      expect(find.text('STATUTORY LEGAL PORTALS'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service & EULA'), findsOneWidget);
      expect(find.text('Account & Data Deletion'), findsOneWidget);
      expect(find.text('Official Web Sanctuary'), findsOneWidget);
      expect(find.text('urheart.asiverticals.me'), findsOneWidget);
    });
  });
}
