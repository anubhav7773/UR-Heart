import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/features/navigation/presentation/screens/sanctuary_navigation_shell.dart';

void main() {
  testWidgets('SanctuaryNavigationShell renders 5 bottom tabs and switches view', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SanctuaryNavigationShell(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Verify all 5 tab items exist
    expect(find.text('Discovery'), findsOneWidget);
    expect(find.text('Resonance'), findsOneWidget);
    expect(find.text('Dialogues'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Persona'), findsOneWidget);

    // Tap on Resonance tab
    await tester.tap(find.text('Resonance'));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on Persona tab
    await tester.tap(find.text('Persona'));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap back to Discovery
    await tester.tap(find.text('Discovery'));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
