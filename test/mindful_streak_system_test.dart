import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/features/profile/domain/user_profile_model.dart';
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/mindful_streak_card.dart';
import 'package:ur_heart/core/ads/ad_reward_models.dart';

void main() {
  group('Mindful Streak & Profile Boost Domain & State Tests', () {
    test('UserProfile.fromJson parses streak, boost points, and reveal tokens',
        () {
      final json = {
        'id': 'user-123',
        'full_name': 'Test Seeker',
        'email': 'seeker@urheart.app',
        'age': 25,
        'gender': 'Man',
        'interested_in': 'Women',
        'streak_count': 5,
        'boost_points': 4,
        'reveal_tokens_count': 2,
        'streak_info': {
          'seconds_remaining': 72000,
        },
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.streakCount, 5);
      expect(profile.boostPoints, 4);
      expect(profile.revealTokensCount, 2);
      expect(profile.secondsRemaining, 72000);
      expect(profile.isStreakActive, isTrue);
    });

    test(
        'GrowthHubController increments streak and boost on daily_streak_boost reward',
        () {
      final controller = GrowthHubController(
        const GrowthHubState(
          streakCount: 3,
          boostPoints: 2,
          secondsRemaining: 10000,
        ),
      );

      expect(controller.state.streakCount, 3);
      expect(controller.state.boostPoints, 2);

      controller.applyReward(AdPlacementTypes.dailyStreakBoost);

      expect(controller.state.streakCount, 4);
      expect(controller.state.boostPoints, 3);
      expect(controller.state.secondsRemaining, 86400);
      expect(controller.state.isStreakActive, isTrue);
    });
  });

  group('MindfulStreakCard Widget Tests', () {
    testWidgets(
        'MindfulStreakCard renders day count, boost percentage, and ad trigger',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          growthHubControllerProvider.overrideWith(
            (ref) => GrowthHubController(
              const GrowthHubState(
                streakCount: 4,
                boostPoints: 3,
                secondsRemaining: 54000,
                revealTokensCount: 2,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MindfulStreakCard(isDark: true, userId: 'user-123'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and badge
      expect(find.text('DAY 4 MINDFUL STREAK'), findsOneWidget);
      expect(find.text('+75% Boost'), findsOneWidget);
      expect(find.textContaining('15h 0m left'), findsOneWidget);

      // Verify loss aversion warning
      expect(find.textContaining('Missing 24h forfeits 1 Social Reveal Token'),
          findsOneWidget);

      // Verify action button
      expect(find.text('Reinforce Streak & Boost (30s)'), findsOneWidget);
    });
  });
}
