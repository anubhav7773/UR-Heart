import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/legal/presentation/grievance_hub_screen.dart';

void main() {
  testWidgets('GrievanceHubScreen renders on narrow screens without overflow', (WidgetTester tester) async {
    // Constrain surface to a narrow 320x640 mobile viewport
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GrievanceHubScreen(),
      ),
    );

    // Allow layout to settle and advance timer
    await tester.pump(const Duration(seconds: 35));

    // Verify title is rendered
    expect(find.text('Legal & Grievance Redressal'), findsOneWidget);

    // Verify no RenderFlex errors were captured
    expect(tester.takeException(), isNull);
  });

  testWidgets('GrievanceHubScreen renders officer card and SLA badges on narrow 320px viewport without overflow', (WidgetTester tester) async {
    // Constrain surface to a narrow 320x640 mobile viewport
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GrievanceHubScreen(
          initialOfficerInfo: {
            'designation': 'Grievance Redressal Officer (Rule 3(2) IT Rules 2021)',
            'officer_name': 'Adv. Vikram Sharma',
            'entity_name': 'ASI Verticals Pvt. Ltd.',
            'email': 'grievance@ur-heart.com',
            'physical_address': 'DLF Cyber City, Tower B, Gurugram, Haryana 122002',
            'acknowledgement_sla': 'Within 24 Hours',
            'resolution_sla': 'Within 15 Days (72h for NCII)',
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and officer details are rendered
    expect(find.text('Legal & Grievance Redressal'), findsOneWidget);
    expect(find.text('Grievance Redressal Officer (Rule 3(2) IT Rules 2021)'), findsOneWidget);
    expect(find.text('Acknowledgment SLA'), findsOneWidget);
    expect(find.text('Resolution SLA'), findsOneWidget);

    // Verify no RenderFlex overflow errors occurred
    expect(tester.takeException(), isNull);
  });
}
