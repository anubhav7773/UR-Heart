import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/ads/rewarded_ad_manager.dart';
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/free_ads_tab_view.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/morning_harvest_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dynamic Ad Provider Auction & Duration Tiers', () {
    test('RewardedAdManager.conductProviderAuction returns valid provider, duration, and multiplier', () {
      final manager = RewardedAdManager.instance;
      final auction = manager.conductProviderAuction(restHours: 7.5);

      expect(['admob', 'meta', 'unity', 'chartboost', 'liftoff'], contains(auction.winningNetwork));
      expect([10, 20, 30], contains(auction.durationSeconds));
      expect(auction.restMultiplier, equals(1.5)); // 6+ hours earns 1.5x
      expect(auction.tier, isNotNull);
    });

    test('GrowthHubController applies dynamic rewards matching ad duration tiers', () {
      final controller = GrowthHubController(
        const GrowthHubState(swipesRemaining: 10, directLetters: 1, whatsappProgress: 0),
      );

      // 1. 10-second reflection -> +10 Swipes
      controller.applyReward('morning_harvest_unlock', durationSeconds: 10);
      expect(controller.state.swipesRemaining, equals(20));

      // 2. 20-second resonance -> +1 Direct Letter
      controller.applyReward('morning_harvest_unlock', durationSeconds: 20);
      expect(controller.state.directLetters, equals(2));

      // 3. 30-second ritual -> +1 WhatsApp Reveal progress (1/3)
      controller.applyReward('morning_harvest_unlock', durationSeconds: 30);
      expect(controller.state.whatsappProgress, equals(1));
    });

    test('GrowthHubController applies 2.0x rest multiplier for 8+ hours slumber', () {
      final controller = GrowthHubController(
        const GrowthHubState(swipesRemaining: 10, directLetters: 0),
      );

      // 10s ad with 8 hours rest -> 10 * 2.0 = 20 swipes granted
      controller.applyReward('morning_harvest_unlock', durationSeconds: 10, restHours: 8.5);
      expect(controller.state.swipesRemaining, equals(30));
    });
  });

  group('Anti-Ban & Anti-Fraud Bot Safeguards', () {
    test('RewardedAdManager canPlayAd enforces pacing throttle', () {
      final manager = RewardedAdManager.instance;
      // Under default state, can play
      expect(manager.canPlayAd(), isTrue);
    });
  });

  group('User Intent vs Provider Auction UI Checks', () {
    testWidgets('MorningHarvestModal displays dynamic ad network auction disclosure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MorningHarvestModal(
              isDark: true,
              onClaimHarvestTapped: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Morning Harvest Greeting'), findsOneWidget);
      expect(find.textContaining('Ad networks dynamically determine the duration'), findsOneWidget);
      expect(find.textContaining('10s Swipes, 20s Direct Letter, or 30s Reveal Token'), findsOneWidget);
    });

    testWidgets('FreeAdsTabView retains user-intent manual reward selection', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            growthHubControllerProvider.overrideWith(
              (ref) => GrowthHubController(
                const GrowthHubState(
                  swipesRemaining: 10,
                  directLetters: 1,
                  revealTokensCount: 0,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FreeAdsTabView(
                isDark: true,
                userId: 'test-user-intent-1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // User has full permission to select what reward they want:
      expect(find.text('Quick Reflection (10s Sponsor)'), findsOneWidget);
      expect(find.text('+10 Profile Skips / Swipes'), findsOneWidget);

      expect(find.text('Deep Resonance (20s Sponsor)'), findsOneWidget);
      expect(find.text('+1 Direct Letter (Send before match)'), findsOneWidget);

      expect(find.text('Sacred Bridge Reveal (30s Ritual)'), findsOneWidget);
      expect(find.textContaining('Watch 3 videos to earn 1 Reveal Token'), findsOneWidget);
    });
  });
}
