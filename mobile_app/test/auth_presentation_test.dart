import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/features/auth/presentation/widgets/auth_header.dart';
import 'package:ruralheart_mobile/features/auth/presentation/widgets/google_auth_button.dart';

void main() {
  testWidgets('AuthHeader displays brand and security badge correctly', (WidgetTester tester) async {
    bool isSignUp = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthHeader(
            isSignUp: isSignUp,
            onModeChanged: (val) => isSignUp = val,
          ),
        ),
      ),
    );

    expect(find.text('UR Heart'), findsOneWidget);
    expect(find.text('Hardware-Locked Security (RSA-2048)'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('GoogleAuthButton renders with Continue with Google label', (WidgetTester tester) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleAuthButton(
            isLoading: false,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    expect(pressed, isTrue);
  });
}
