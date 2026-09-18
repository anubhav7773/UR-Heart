import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/legal/presentation/grievance_hub_screen.dart';

void main() {
  testWidgets('GrievanceHubScreen renders title, statutory tabs, and file grievance FAB', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GrievanceHubScreen(),
      ),
    );

    // Verify AppBar Title
    expect(find.text('Legal & Grievance Redressal'), findsOneWidget);

    // Verify Statutory Compliance & Ticket Tabs
    expect(find.text('Grievance Officer & SLA'), findsOneWidget);
    expect(find.text('My Filed Tickets'), findsOneWidget);

    // Verify File Grievance Floating Action Button
    expect(find.text('File Grievance'), findsOneWidget);
    expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);
  });
}
