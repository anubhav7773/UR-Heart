import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RuralHeartApp());
    expect(find.byType(RuralHeartApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
