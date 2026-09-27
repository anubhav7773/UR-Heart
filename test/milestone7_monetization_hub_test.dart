import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/ads/ad_reward_models.dart';
import 'package:ur_heart/core/ads/rewarded_ad_manager.dart';
import 'package:ur_heart/core/billing/sanctuary_billing_service.dart';
import 'package:ur_heart/features/rewards/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/rewards/presentation/screens/growth_hub_screen.dart';
import 'package:ur_heart/features/rewards/presentation/services/slumber_sensor_service.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/morning_harvest_modal.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/sovereign_store_tab_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RewardedAdManager.instance.resetAndPreload();
    SanctuaryBillingService.instance.resetForTesting();
  });

  group('Milestone 7: Exit Criteria 1 & 2 - Ad Engine & SSV Verification', () {
    test('Check 1: Double-buffer FIFO preloading and zero-delay SSV customData', () async {
      final manager = RewardedAdManager.instance;
      expect(manager.isAdReady, isTrue);
      expect(manager.primaryBufferAd, isNotNull);
      expect(manager.secondaryBufferAd, isNotNull);

      const userId = 'user-m7-uuid';
      bool rewardGranted = false;

      await manager.showRewardedAd(
        userId: userId,
        adType: 'quick_reflection',
        targetId: 'none',
        onRewardGranted: () => rewardGranted = true,
      );

      expect(rewardGranted, isTrue);
      expect(
        manager.lastCustomDataTransmitted,
        equals('$userId:quick_reflection:none'),
      );
      // Secondary shifted to primary
      expect(manager.primaryBufferAd, isNotNull);
    });

    test('Check 2: SSV Server Credit Verification updates swipes (+10)', () async {
      final controller = GrowthHubController(
        const GrowthHubState(swipesRemaining: 15, directLetters: 0),
      );

      await controller.triggerRewardedAd(
        adType: AdPlacementTypes.quickReflection,
        userId: 'user-ssv-123',
      );

      expect(controller.state.swipesRemaining, equals(25));
    });
  });

  group('Milestone 7: Exit Criterion 3 - Sovereign Ad-Free Gate Assertion', () {
    testWidgets('Check 3: Suppresses ad prompts when subscriber active', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final billing = SanctuaryBillingService.instance;
      await billing.purchasePackage('urheart_pass_monthly');
      expect(billing.isAdFree, isTrue);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GrowthHubScreen(userId: 'sovereign-user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sovereign banner is visible and ad placement cards are suppressed
      expect(find.text('SOVEREIGN SILENCE ACTIVE'), findsOneWidget);
      expect(find.text('Quick Reflection (10s Sponsor)'), findsNothing);
      expect(find.text('Deep Resonance (20s Sponsor)'), findsNothing);
    });
  });

  group('Milestone 7: Exit Criterion 4 - Anti-Ban Slumber Engine Check', () {
    testWidgets('Check 4: Slumber mode pickup triggers MorningHarvestModal (+20, +2)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GrowthHubScreen(userId: 'slumber-pickup-user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle Slumber Mode
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(SlumberSensorService.instance.isMonitoring, isTrue);

      // Simulate device pickup
      SlumberSensorService.instance.triggerMorningPickupWakeEvent();
      await tester.pumpAndSettle();

      expect(find.byType(MorningHarvestModal), findsOneWidget);
      expect(find.text('Claim Morning Harvest'), findsOneWidget);

      await tester.tap(find.text('Claim Morning Harvest'));
      await tester.pumpAndSettle();

      expect(
        RewardedAdManager.instance.lastCustomDataTransmitted,
        equals('slumber-pickup-user:morning_harvest_unlock:none'),
      );

      final state = container.read(growthHubControllerProvider);
      expect(state.swipesRemaining, equals(45)); // 25 initial + 20
      expect(state.directLetters, equals(3)); // 1 initial + 2
    });
  });

  group('Milestone 7: Exit Criterion 5 - Web Store Uplink Integrity', () {
    test('Check 5: Web Store URL matches https://urheart.asiverticals.me/store', () {
      expect(
        SovereignStoreTabView.storeWebUrl,
        equals('https://urheart.asiverticals.me/store'),
      );
    });

    testWidgets('Tab B renders Sovereign Store and Web Uplink banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GrowthHubScreen(userId: 'store-user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Sovereign Pass Tab
      await tester.tap(find.text('👑 Sovereign Pass'));
      await tester.pumpAndSettle();

      expect(find.text('SANCTUARY SOVEREIGN PRIVILEGE'), findsOneWidget);
      expect(find.text('Sanctuary Web Store (10% Extra Passes)'), findsOneWidget);
      expect(find.text('SOVEREIGN PASSES'), findsOneWidget);
      expect(find.text('A LA CARTE MICRO-PACKS'), findsOneWidget);
      expect(find.text('Restore Purchases (Google Play)'), findsOneWidget);
    });
  });
}
