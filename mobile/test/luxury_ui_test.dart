import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/widgets/luxury_empty_card.dart';
import 'package:ur_heart/features/feed/presentation/widgets/radar_sonar_empty_state.dart';

void main() {
  testWidgets('RadarSonarEmptyState animates without throwing exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RadarSonarEmptyState(
            city: 'Lucknow',
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('Searching for Resonant Hearts'), findsOneWidget);
    expect(find.text('Active Range: Lucknow + 25 km'), findsOneWidget);

    // Pump frames to ensure CustomPainter animates without RenderFlex issues
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LuxuryEmptyCard renders title, description, and action button', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LuxuryEmptyCard(
            icon: Icons.favorite,
            accentColor: const Color(0xFFFF2E63),
            title: 'No Matches',
            description: 'Start swiping to find mutual matches.',
            actionLabel: 'Explore Feed',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No Matches'), findsOneWidget);
    expect(find.text('Explore Feed'), findsOneWidget);

    await tester.tap(find.text('Explore Feed'));
    expect(tapped, isTrue);
  });
}
