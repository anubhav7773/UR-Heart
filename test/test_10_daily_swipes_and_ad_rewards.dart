import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/rewards/presentation/controllers/rewards_controller.dart';
import 'package:ur_heart/features/rewards/domain/rewards_models.dart';
import 'package:ur_heart/core/ads/ad_reward_models.dart';
import 'package:ur_heart/features/settings/presentation/screens/sanctuary_app_info_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('10 Daily Intentional Swipes & Ad Replenishment Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('New User starts with strictly 10 swipes, 0 direct letters, and 0 WA progress', () async {
      final controller = RewardsController();
      await controller.loadSavedState();

      expect(controller.state.swipesRemaining, equals(10));
      expect(controller.state.directLettersCount, equals(0));
      expect(controller.state.whatsappProgress, equals(0));
      expect(controller.state.peerWhatsappProgress, equals(0));
    });

    test('Watching 10s quick_reflection ad replenishes exactly +10 swipes', () async {
      final controller = RewardsController(const RewardHubState(swipesRemaining: 10));

      await controller.applyReward(AdPlacementTypes.quickReflection);

      expect(controller.state.swipesRemaining, equals(20));
    });

    testWidgets('SanctuaryAppInfoScreen renders 10 Mindful Swipes / Day pillar correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SanctuaryAppInfoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10 Mindful Swipes / Day'), findsOneWidget);
      expect(find.textContaining('High-intent discovery capped at 10 daily intentional swipes'), findsOneWidget);
      expect(find.textContaining('+10 swipes anytime by taking a 10s mindful reflection ad'), findsOneWidget);
    });
  });
}
