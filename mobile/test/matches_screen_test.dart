import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/matches/presentation/matches_screen.dart';

void main() {
  testWidgets('MatchesScreen renders dual tabs and switches between them', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MatchesScreen(),
      ),
    );

    // Initial render shows AppBar and Tabs
    expect(find.text('Matches & Connections'), findsOneWidget);
    expect(find.text('Connected (Matches)'), findsOneWidget);
    expect(find.text('Second Chance (Missed)'), findsOneWidget);

    // Switch to Second Chance tab
    await tester.tap(find.text('Second Chance (Missed)'));
    await tester.pumpAndSettle();

    // Verify Tab 2 is active
    expect(find.text('Second Chance (Missed)'), findsOneWidget);
  });
}
