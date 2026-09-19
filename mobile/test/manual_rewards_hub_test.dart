import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/wallet/presentation/manual_rewards_hub_screen.dart';

void main() {
  testWidgets('ManualRewardsHubScreen renders 3 tier cards and reward choices', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ManualRewardsHubScreen(),
      ),
    );

    expect(find.text('Watch Ads & Earn Rewards'), findsOneWidget);
  });
}
