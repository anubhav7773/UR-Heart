import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/auth/presentation/profile_setup_screen.dart';

void main() {
  testWidgets('ProfileSetupScreen renders inputs and toggles LGBTQ+ chip correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(),
      ),
    );

    // Verify presence of core form fields
    expect(find.text('Legal Full Name / पूरा नाम'), findsOneWidget);
    expect(find.text('WhatsApp Number / व्हाट्सएप नंबर'), findsOneWidget);
    expect(find.text('Gender Identity / लिंग पहचान'), findsOneWidget);
    expect(find.text('City & Discovery Area / शहर'), findsOneWidget);

    // Verify all 3 gender options exist
    expect(find.text('♂️ Male'), findsOneWidget);
    expect(find.text('♀️ Female'), findsOneWidget);
    expect(find.text('🏳️🌈 LGBTQ+'), findsOneWidget);

    // Tap LGBTQ+ gender chip
    await tester.tap(find.text('🏳️🌈 LGBTQ+'));
    await tester.pumpAndSettle();

    // Verify submission button
    final ctaButton = find.text('Continue to Photos & KYC / आगे बढ़ें →');
    expect(ctaButton, findsOneWidget);

    await tester.ensureVisible(ctaButton);
    await tester.pumpAndSettle();

    // Tap submit with empty fields to trigger validation error messages
    await tester.tap(ctaButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    expect(find.text('Enter valid 10-digit mobile number.'), findsOneWidget);
  });
}
