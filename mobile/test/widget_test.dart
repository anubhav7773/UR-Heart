import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/main.dart';
import 'package:ur_heart/features/auth/presentation/onboarding_screen.dart';

void main() {
  testWidgets('URHeartApp startup smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const URHeartApp());

    // Verify OnboardingScreen loads
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
