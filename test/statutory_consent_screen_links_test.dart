import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/features/auth/presentation/widgets/statutory_links_card.dart';
import 'package:ur_heart/features/auth/presentation/screens/consent_screen.dart';

void main() {
  group('Statutory Legal & Data Deletion Links on Consent Screen', () {
    testWidgets('StatutoryLinksCard renders all 4 mandatory links with external launch icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatutoryLinksCard(isDark: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & subtitles
      expect(find.text('STATUTORY LEGAL PORTALS'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service & EULA'), findsOneWidget);
      expect(find.text('Account & Data Deletion'), findsOneWidget);
      expect(find.text('Official Web Sanctuary'), findsOneWidget);

      // Verify open in new icons
      expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(4));
    });

    testWidgets('ConsentScreen renders StatutoryLinksCard, affirmation links, and footer links', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ConsentScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify StatutoryLinksCard presence
      expect(find.byType(StatutoryLinksCard), findsOneWidget);

      // Verify inline affirmation browser links
      expect(find.text('Read Terms of Service in browser'), findsOneWidget);
      expect(find.text('Read DPDP Privacy Policy in browser'), findsOneWidget);

      // Verify footer statutory links
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Terms & EULA'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });
  });
}
