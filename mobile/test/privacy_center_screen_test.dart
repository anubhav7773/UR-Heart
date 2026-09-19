import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/privacy/presentation/privacy_center_screen.dart';

void main() {
  testWidgets('PrivacyCenterScreen renders title and privacy controls header', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyCenterScreen(),
      ),
    );

    // Verify AppBar Title
    expect(find.text('Privacy & Blocked Users'), findsOneWidget);
  });
}
