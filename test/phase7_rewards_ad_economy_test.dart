import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/ads/ad_reward_models.dart';
import 'package:ur_heart/core/ads/rewarded_ad_manager.dart';
import 'package:ur_heart/features/rewards/domain/rewards_models.dart';
import 'package:ur_heart/features/rewards/presentation/controllers/rewards_controller.dart';
import 'package:ur_heart/features/rewards/presentation/screens/growth_hub_screen.dart';
import 'package:ur_heart/features/rewards/presentation/services/slumber_sensor_service.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/enclave_reveal_modal.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/morning_harvest_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RewardedAdManager.instance.resetAndPreload();
  });

  group('Phase 7 - Zero-Latency Double-Buffered Ad Manager Tests', () {
    test('Check 1: Double-buffer FIFO preloading and zero-latency ad playback', () async {
      final manager = RewardedAdManager.instance;
      expect(manager.isAdReady, isTrue);
      expect(manager.primaryBufferAd, isNotNull);
      expect(manager.secondaryBufferAd, isNotNull);

      final initialPrimaryId = manager.primaryBufferAd?.id;
      final initialSecondaryId = manager.secondaryBufferAd?.id;

      AdRewardEvent? receivedEvent;
      final success = await manager.showRewardedAd(
        userId: 'test-user-123',
        adType: AdPlacementTypes.quickReflection,
        onClientRewardVerified: (event) {
          receivedEvent = event;
        },
      );

      expect(success, isTrue);
      expect(receivedEvent, isNotNull);
      expect(receivedEvent?.adType, equals(AdPlacementTypes.quickReflection));
      // Primary shifted to previous secondary
      expect(manager.primaryBufferAd?.id, equals(initialSecondaryId));
      expect(manager.primaryBufferAd?.id, isNot(equals(initialPrimaryId)));
    });

    test('Check 2: SSV Custom Data Integrity ({userId}:{adType}:{targetId})', () async {
      final manager = RewardedAdManager.instance;
      const testUserId = '88888888-8888-8888-8888-888888888888';
      const targetMatchId = 'match-uuid-999';

      await manager.showRewardedAd(
        userId: testUserId,
        adType: AdPlacementTypes.quickReflection,
      );
      expect(manager.lastCustomDataTransmitted, equals('$testUserId:quick_reflection:none'));

      await manager.showRewardedAd(
        userId: testUserId,
        adType: AdPlacementTypes.whatsappReveal,
        targetId: targetMatchId,
      );
      expect(
        manager.lastCustomDataTransmitted,
        equals('$testUserId:whatsapp_reveal:$targetMatchId'),
      );
    });
  });

  group('Phase 7 - Reward Attribution & State Machine Tests', () {
    test('Check 3: Reward attribution (+10 Swipes, +1 Direct Letter, +20 Morning Harvest)', () async {
      final controller = RewardsController(
        const RewardHubState(swipesRemaining: 25, directLettersCount: 1),
      );

      // Quick Reflection -> +10 Swipes
      await controller.applyReward(AdPlacementTypes.quickReflection);
      expect(controller.state.swipesRemaining, equals(35));
      expect(controller.state.directLettersCount, equals(1));

      // Deep Resonance -> +1 Direct Letter
      await controller.applyReward(AdPlacementTypes.deepResonance);
      expect(controller.state.swipesRemaining, equals(35));
      expect(controller.state.directLettersCount, equals(2));

      // Morning Harvest Unlock -> +20 Swipes, +2 Direct Letters
      await controller.applyReward(AdPlacementTypes.morningHarvestUnlock);
      expect(controller.state.swipesRemaining, equals(55));
      expect(controller.state.directLettersCount, equals(4));
    });

    test('Check 4: Bilateral WhatsApp Progress State Machine (Dual-sided 3/3)', () async {
      final controller = RewardsController(
        const RewardHubState(
          whatsappProgress: 1,
          peerWhatsappProgress: 2,
        ),
      );

      expect(controller.state.isWhatsappUnlocked, isFalse);

      // User advances to 2/3
      await controller.applyReward(AdPlacementTypes.whatsappReveal);
      expect(controller.state.whatsappProgress, equals(2));
      expect(controller.state.isWhatsappUnlocked, isFalse);

      // User advances to 3/3 (User complete, Peer still 2/3)
      await controller.applyReward(AdPlacementTypes.whatsappReveal);
      expect(controller.state.whatsappProgress, equals(3));
      expect(controller.state.isWhatsappUnlocked, isFalse);

      // Peer advances to 3/3 -> Bilateral unlock achieved!
      await controller.advancePeerWhatsappProgress(3);
      expect(controller.state.peerWhatsappProgress, equals(3));
      expect(controller.state.isWhatsappUnlocked, isTrue);
      expect(controller.state.ephemeralWhatsappLink, contains('wa.me'));
    });
  });

  group('Phase 7 - Anti-Ban Slumber Compliance & Widget Tests', () {
    testWidgets('Check 5: Slumber mode zero background ad loops and morning interactive pickup',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GrowthHubScreen(userId: 'user-slumber-test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen 10 editorial elements
      expect(find.text('Growth PRO · REWARDS HUB'), findsOneWidget);
      expect(find.text('100% FREE SANCTUARY · ZERO PAYWALLS'), findsOneWidget);
      expect(find.text('Swipes Remaining'), findsOneWidget);
      expect(find.text('Night Sanctuary Slumber'), findsOneWidget);

      // Toggle Slumber Mode
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Policy compliance verification: SlumberSensorService is listening, zero ad requests made
      expect(SlumberSensorService.instance.isMonitoring, isTrue);

      // Morning pickup wake event occurs
      SlumberSensorService.instance.triggerMorningPickupWakeEvent();
      await tester.pumpAndSettle();

      // Morning Harvest Greeting Modal appears with interactive button
      expect(find.byType(MorningHarvestModal), findsOneWidget);
      expect(find.text('Morning Harvest Greeting'), findsOneWidget);
      expect(find.text('Claim Morning Harvest'), findsOneWidget);

      // Tap Claim Morning Harvest
      await tester.tap(find.text('Claim Morning Harvest'));
      await tester.pumpAndSettle();

      // Verify customData matches morning_harvest_unlock
      expect(
        RewardedAdManager.instance.lastCustomDataTransmitted,
        equals('user-slumber-test:morning_harvest_unlock:none'),
      );
    });

    testWidgets('Screen 10: User initiated Quick Reflection playback test', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GrowthHubScreen(userId: 'test-ad-user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Quick Reflection
      final watchButtons = find.text('Watch');
      expect(watchButtons, findsWidgets);

      await tester.tap(watchButtons.first);
      await tester.pumpAndSettle();

      // Verify instant playback without loading spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        RewardedAdManager.instance.lastCustomDataTransmitted,
        equals('test-ad-user:quick_reflection:none'),
      );
    });

    testWidgets('Enclave Reveal Modal: Bilateral unlocks WhatsApp button when 3/3', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool whatsAppOpened = false;

      // Pumping modal in unlocked state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnclaveRevealModal(
              userProgress: 3,
              peerProgress: 3,
              matchName: 'Ananya',
              isUnlocked: true,
              onWatchRevealAd: () {},
              onOpenWhatsApp: () {
                whatsAppOpened = true;
              },
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sacred Enclave Unlocked'), findsOneWidget);
      final openButton = find.text('Open WhatsApp Directly ➔');
      expect(openButton, findsOneWidget);

      await tester.tap(openButton);
      await tester.pumpAndSettle();
      expect(whatsAppOpened, isTrue);
    });
  });
}
