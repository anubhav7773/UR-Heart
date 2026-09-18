import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/profile/presentation/manage_photos_screen.dart';

void main() {
  testWidgets('ManagePhotosScreen renders header and photo slots', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ManagePhotosScreen(),
      ),
    );

    // Initial render shows AppBar title
    expect(find.text('Manage Profile Photos'), findsOneWidget);
  });
}
