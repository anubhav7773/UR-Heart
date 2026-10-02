import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ur_heart_consent_given': true,
    });
  });

  testWidgets('URHeartApp root widget renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: URHeartApp(initialRoute: '/consent'),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
