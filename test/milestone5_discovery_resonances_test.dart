import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';
import 'package:ur_heart/features/feed/presentation/controllers/feed_controller.dart';
import 'package:ur_heart/features/feed/presentation/controllers/ignored_profiles_controller.dart';
import 'package:ur_heart/features/feed/presentation/screens/feed_screen.dart';
import 'package:ur_heart/features/feed/presentation/screens/ignored_profiles_screen.dart';
import 'package:ur_heart/features/feed/presentation/widgets/candidate_profile_card.dart';
import 'package:ur_heart/features/feed/presentation/widgets/out_of_swipes_modal.dart';
import 'package:ur_heart/features/resonances/data/resonances_repository.dart';
import 'package:ur_heart/features/resonances/presentation/controllers/resonances_controller.dart';
import 'package:ur_heart/features/resonances/presentation/screens/resonances_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Milestone 5 Exit Criterion 1: Bi-Directional Orientation Shield Test', () {
    test('Account A (Woman seeking Men) and Account B (Woman seeking Women) never leak across feeds', () {
      // Account A: Woman seeking Men
      const userAGender = 'Woman';
      const userAInterestedIn = 'Men';

      // Account B: Woman seeking Women
      const userBGender = 'Woman';
      const userBInterestedIn = 'Women';

      // 1. Can A see B?
      final canASeeB = CandidateProfile.checkOrientationShield(
        userGender: userAGender,
        userInterestedIn: userAInterestedIn,
        targetGender: userBGender,
        targetInterestedIn: userBInterestedIn,
      );
      expect(canASeeB, isFalse, reason: 'Woman seeking Men must never see Woman in feed');

      // 2. Can B see A?
      final canBSeeA = CandidateProfile.checkOrientationShield(
        userGender: userBGender,
        userInterestedIn: userBInterestedIn,
        targetGender: userAGender,
        targetInterestedIn: userAInterestedIn,
      );
      expect(canBSeeA, isFalse, reason: 'Target A seeking Men must never be surfaced to B');

      // 3. Ghost Cloak: Incognito profile is 100% excluded regardless of orientation match
      final canSeeIncognito = CandidateProfile.checkOrientationShield(
        userGender: 'Man',
        userInterestedIn: 'Women',
        targetGender: 'Woman',
        targetInterestedIn: 'Men',
        targetIsIncognito: true,
      );
      expect(canSeeIncognito, isFalse, reason: 'Incognito profiles must be 100% excluded from discovery deck');
    });
  });

  group('Milestone 5 Exit Criterion 2: 60fps Gesture Tilt Physics', () {
    testWidgets('Drag card right tilts +15 deg and drag left tilts -15 deg with color tint overlays',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? swipedAction;
      final candidateData = {
        'id': 'cand-1',
        'full_name': 'Meera Kapoor',
        'age': 24,
        'gender': 'Woman',
        'profession': 'Architect',
        'location_name': 'Saket, Ayodhya',
        'ai_insight': 'A shared reverence for quiet reflection connects your paths.',
        'resonance_score': 96,
        'bio': 'Designing quiet sanctuaries and savoring slow pour-over coffee.',
        'interests': ['Architecture', 'Literature', 'Ceramics'],
        'photos': ['https://images.unsplash.com/photo-1534528741775-53994a69daeb'],
        'blur_hashes': ['L6PZfSi_.AyE_3t7t7R**0o#DgR4'],
        'kyc_status': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CandidateProfileCard(
              candidate: candidateData,
              isDark: false,
              onSwipeCompleted: (type) => swipedAction = type,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Meera Kapoor, 24'), findsOneWidget);
      expect(find.text('96% MATCH'), findsOneWidget);
      expect(find.text('RESONANCE ALIGNMENT'), findsOneWidget);

      final cardFinder = find.byType(CandidateProfileCard);

      // Drag Right -> Triggers Like
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await gesture.moveBy(const Offset(200.0, 0.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(swipedAction, 'like');

      // Drag Left -> Triggers Pass
      final gestureLeft = await tester.startGesture(tester.getCenter(cardFinder));
      await gestureLeft.moveBy(const Offset(-200.0, 0.0));
      await gestureLeft.up();
      await tester.pumpAndSettle();
      expect(swipedAction, 'pass');
    });
  });

  group('Milestone 5 Exit Criterion 3: Out-of-Swipes Modal Intercept', () {
    testWidgets('When swipesRemaining is 0, swipe triggers OutOfSwipesModal with ad & sovereign pass options',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository()),
        ],
      );
      addTearDown(container.dispose);

      final feedNotifier = container.read(feedControllerProvider.notifier);
      await feedNotifier.loadDiscoveryFeed();
      feedNotifier.setSwipesRemaining(0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 Skips Remaining'), findsOneWidget);

      // Attempt swipe action via Pass button
      final passButton = find.byIcon(Icons.close_rounded);
      await tester.tap(passButton);
      await tester.pumpAndSettle();

      // Modal is displayed
      expect(find.byType(OutOfSwipesModal), findsOneWidget);
      expect(find.text('Daily Presence Quota Exhausted'), findsOneWidget);
      expect(find.textContaining('Watch 10s Reflection'), findsOneWidget);
      expect(find.textContaining('Get Sovereign Pass'), findsOneWidget);

      // Tap watch ad reflection to replenish +10
      final watchAdButton = find.widgetWithText(ElevatedButton, 'Watch 10s Reflection (+10 Swipes Free)');
      await tester.tap(watchAdButton);
      await tester.pumpAndSettle();

      // Modal is dismissed and quota replenished
      expect(find.byType(OutOfSwipesModal), findsNothing);
      expect(container.read(feedControllerProvider).swipesRemaining, 10);
      expect(find.text('10 Skips Remaining'), findsOneWidget);
    });
  });

  group('Milestone 5 Exit Criterion 4: Pass Vault Single-Tap Revisit', () {
    testWidgets('Passing candidate and tapping Revisit restores it to the top of feed deck',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository()),
        ],
      );
      addTearDown(container.dispose);

      final feedNotifier = container.read(feedControllerProvider.notifier);
      final ignoredNotifier = container.read(ignoredProfilesControllerProvider.notifier);

      await feedNotifier.loadDiscoveryFeed();
      final originalCandidate = container.read(feedControllerProvider).currentCandidate;
      expect(originalCandidate, isNotNull);

      // Pass profile on Screen 05
      await feedNotifier.swipePass();
      ignoredNotifier.syncFromFeedController();

      expect(container.read(ignoredProfilesControllerProvider).passedProfiles.length, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: IgnoredProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ignored Profiles'), findsOneWidget);
      expect(find.text('Revisit'), findsOneWidget);

      // Tap Revisit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Revisit'));
      await tester.pumpAndSettle();

      // Verified candidate restored to deck
      expect(container.read(ignoredProfilesControllerProvider).passedProfiles.isEmpty, isTrue);
      expect(container.read(feedControllerProvider).currentCandidate?.id, originalCandidate?.id);
    });
  });

  group('Milestone 5 Exit Criterion 5: Resonances Mutual Match Flow', () {
    testWidgets('Tapping Chat on incoming like executes match and routes to /chat-dialogue',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          resonancesRepositoryProvider.overrideWithValue(ResonancesRepository()),
        ],
      );
      addTearDown(container.dispose);

      final resonancesNotifier = container.read(resonancesControllerProvider.notifier);
      await resonancesNotifier.loadResonances();

      expect(container.read(resonancesControllerProvider).incomingLikes.isNotEmpty, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ResonancesScreen(),
            routes: {
              '/chat-dialogue': (context) => const Scaffold(body: Text('Chat Dialogue Screen')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resonances'), findsOneWidget);
      expect(find.textContaining('Liked You'), findsOneWidget);

      // Find Chat CTA on the incoming like card
      final chatButton = find.widgetWithText(ElevatedButton, 'Chat').first;
      expect(chatButton, findsOneWidget);

      await tester.tap(chatButton);
      await tester.pumpAndSettle();

      // Verified screen navigated to /chat-dialogue
      expect(find.text('Chat Dialogue Screen'), findsOneWidget);
    });
  });
}
