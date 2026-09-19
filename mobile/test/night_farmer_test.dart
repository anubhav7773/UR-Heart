import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/wallet/presentation/night_farmer_screen.dart';

void main() {
  testWidgets('NightFarmerScreen renders AMOLED ambient layout and exit button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NightFarmerScreen(),
      ),
    );

    expect(find.text('NIGHT FARMER ACTIVE'), findsOneWidget);
    expect(find.text('Stop Farming & Collect Rewards'), findsOneWidget);
  });
}
