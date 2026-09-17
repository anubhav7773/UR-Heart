import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/auth/presentation/auth_gate.dart';

void main() {
  testWidgets('AuthGate displays OnboardingScreen when user is unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStream: Stream.value(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UR-Heart'), findsOneWidget);
    expect(find.text('100% Free Desi Dating\nमुफ़्त और सुरक्षित मेल-जोल'), findsOneWidget);
  });
}
