import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/auth/presentation/profile_setup_screen.dart';
import 'package:ur_heart/features/onboarding/presentation/widgets/gender_selector_bottom_sheet.dart';

void main() {
  testWidgets('ProfileSetupScreen renders inputs and opens gender spectrum bottom sheet correctly', (WidgetTester tester) async {
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

    // Verify gender identity selector prompt exists
    expect(find.text('Select your gender identity...'), findsOneWidget);

    // Tap gender selector to open bottom sheet
    await tester.tap(find.text('Select your gender identity...'));
    await tester.pumpAndSettle();

    // Verify spectrum options in bottom sheet
    expect(find.text('Non-Binary'), findsOneWidget);
    expect(find.text('Transgender Woman (Trans Female)'), findsOneWidget);
    expect(find.text('Man (पुरुष)'), findsOneWidget);

    // Select Non-Binary
    await tester.tap(find.text('Non-Binary'));
    await tester.pumpAndSettle();

    // Verify selected gender identity is displayed
    expect(find.text('Non-Binary'), findsOneWidget);

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
