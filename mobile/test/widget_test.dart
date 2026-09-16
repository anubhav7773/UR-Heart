import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/chat/presentation/whatsapp_reveal_sheet.dart';

void main() {
  testWidgets('WhatsAppRevealSheet render test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WhatsAppRevealSheet(
            userAdsWatched: 2,
            matchAdsWatched: 1,
          ),
        ),
      ),
    );

    // Verify WhatsAppRevealSheet renders correctly with progress badges
    expect(find.text('2 of 3 Watched'), findsOneWidget);
    expect(find.text('1 of 3 Watched'), findsOneWidget);
  });
}
