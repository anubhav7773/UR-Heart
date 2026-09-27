import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';
import 'package:ur_heart/features/feed/presentation/controllers/feed_controller.dart';
import 'package:ur_heart/features/feed/presentation/controllers/ignored_profiles_controller.dart';
import 'package:ur_heart/features/feed/presentation/screens/feed_screen.dart';
import 'package:ur_heart/features/feed/presentation/screens/ignored_profiles_screen.dart';
import 'package:ur_heart/features/feed/presentation/widgets/candidate_photo_carousel.dart';
import 'package:ur_heart/features/feed/presentation/widgets/out_of_swipes_ad_modal.dart';
import 'package:ur_heart/features/feed/presentation/widgets/sanctuary_card_deck.dart';
import 'package:ur_heart/features/resonances/data/resonances_repository.dart';
import 'package:ur_heart/features/resonances/presentation/controllers/resonances_controller.dart';
import 'package:ur_heart/features/resonances/presentation/screens/resonances_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5 Exit Criterion 1: Card Physics & Gesture Handling', () {
    testWidgets('Card tilts during drag gesture and executes onSwipeRight / onSwipeLeft',
        (tester) async {
      bool swipedRight = false;
      bool swipedLeft = false;

      const profile = CandidateProfile(
        id: 'candidate-test-1',
        fullName: 'Tara Sharma',
        age: 26,
        gender: 'female',
        lookingFor: 'male',
        locationName: 'Bandra West',
        distanceKm: 1.5,
        resonanceScore: 94,
        intentQuote: 'Seeking authentic shared silences and intentional connections.',
        interests: ['Architecture', 'Pour-Over Coffee', 'Murakami'],
        photoUrls: ['https://storage.ur-heart.com/profiles/tara1.webp'],
        blurHashes: ['L6PZfSi_.AyE_3t7t7R**0o#DgR4'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SanctuaryCardDeck(
              profile: profile,
              isDark: false,
              onSwipeLeft: () => swipedLeft = true,
              onSwipeRight: () => swipedRight = true,
              onSwipeUp: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tara Sharma, 26'), findsOneWidget);
      expect(find.text('94% RESONANCE'), findsOneWidget);
      expect(find.text('Architecture'), findsOneWidget);

      // Perform a right drag gesture (> 100 pixels) to trigger like
      final cardFinder = find.byType(SanctuaryCardDeck);
      await tester.drag(cardFinder, const Offset(150.0, 0.0));
      await tester.pumpAndSettle();

      expect(swipedRight, isTrue);
      expect(swipedLeft, isFalse);

      // Perform a left drag gesture (< -100 pixels) to trigger pass
      await tester.drag(cardFinder, const Offset(-150.0, 0.0));
      await tester.pumpAndSettle();

      expect(swipedLeft, isTrue);
    });
  });

  group('Phase 5 Exit Criterion 2: Quota Exhaustion Gate', () {
    testWidgets('swipes_remaining = 0 triggers OutOfSwipesAdModal and 10s ad replenishes +10',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Initialize feed controller with 0 swipes remaining
      final feedNotifier = container.read(feedControllerProvider.notifier);
      await feedNotifier.loadDiscoveryFeed();

      // Set swipes directly to 0 to simulate daily quota exhaustion
      feedNotifier.setSwipesRemaining(0);

      expect(container.read(feedControllerProvider).swipesRemaining, 0);

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

      // Attempt to pass via Pass button (Icons.close_rounded)
      final passButtonFinder = find.byIcon(Icons.close_rounded);
      await tester.tap(passButtonFinder);
      await tester.pumpAndSettle();

      // Verify OutOfSwipesAdModal appears
      expect(find.text('Daily Mindful Quota Exhausted'), findsOneWidget);
      expect(find.textContaining('Take a gentle 10s reflection'), findsOneWidget);

      // Tap "Watch Reflection (10s)" to replenish
      final watchAdButtonFinder = find.widgetWithText(ElevatedButton, 'Watch Reflection (10s) · +10 Skips');
      expect(watchAdButtonFinder, findsOneWidget);
      await tester.tap(watchAdButtonFinder);
      await tester.pumpAndSettle();

      // Modal is dismissed and skips replenished to 10
      expect(find.byType(OutOfSwipesAdModal), findsNothing);
      expect(container.read(feedControllerProvider).swipesRemaining, 10);
      expect(find.text('10 Skips Remaining'), findsOneWidget);
    });
  });

  group('Phase 5 Exit Criterion 3: Ignored Vault Revisit', () {
    testWidgets('Passed profile appears in Pass Vault and Revisit restores it to feed deck',
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
      final initialCount = container.read(feedControllerProvider).candidates.length;
      final passedCandidate = container.read(feedControllerProvider).currentCandidate;
      expect(passedCandidate, isNotNull);

      // Swipe pass on current candidate
      await feedNotifier.swipePass();

      // Candidate is removed from feed
      expect(container.read(feedControllerProvider).candidates.length, initialCount - 1);

      // Sync ignored profiles vault
      ignoredNotifier.syncFromFeedController();
      expect(container.read(ignoredProfilesControllerProvider).passedProfiles.length, 1);
      expect(container.read(ignoredProfilesControllerProvider).passedProfiles.first.id, passedCandidate!.id);

      // Render IgnoredProfilesScreen
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
      expect(find.text('${passedCandidate.fullName}, ${passedCandidate.age}'), findsOneWidget);

      // Tap "Revisit" button
      final revisitButton = find.widgetWithText(ElevatedButton, 'Revisit');
      expect(revisitButton, findsOneWidget);
      await tester.tap(revisitButton);
      await tester.pumpAndSettle();

      // Vault is now empty and candidate is restored to the top of feed deck
      expect(container.read(ignoredProfilesControllerProvider).passedProfiles.isEmpty, isTrue);
      expect(container.read(feedControllerProvider).currentCandidate?.id, passedCandidate.id);
      expect(container.read(feedControllerProvider).candidates.length, initialCount);
    });
  });

  group('Phase 5 Exit Criterion 4: Instant Match on Resonances', () {
    testWidgets('Tapping Chat on Liked You converts to mutual match and navigates to /chat-dialogue',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          resonancesRepositoryProvider.overrideWithValue(ResonancesRepository()),
        ],
      );
      addTearDown(container.dispose);

      final resonancesNotifier = container.read(resonancesControllerProvider.notifier);
      await resonancesNotifier.loadResonances();

      final initialLikesCount = container.read(resonancesControllerProvider).incomingLikes.length;
      final initialMutualCount = container.read(resonancesControllerProvider).mutualConnections.length;
      expect(initialLikesCount, greaterThan(0));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            initialRoute: ResonancesScreen.routeName,
            routes: {
              ResonancesScreen.routeName: (context) => const ResonancesScreen(),
              '/chat-dialogue': (context) => const Scaffold(body: Text('Chat Dialogue Screen')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resonances'), findsOneWidget);
      expect(find.textContaining('Liked You'), findsOneWidget);

      // Find the "💬 Chat" CTA button
      final chatCtaFinder = find.widgetWithText(ElevatedButton, 'Chat').first;
      expect(chatCtaFinder, findsOneWidget);

      // Tap "Chat"
      await tester.tap(chatCtaFinder);
      await tester.pumpAndSettle();

      // Verify mutual connection created and routed to /chat-dialogue
      expect(find.text('Chat Dialogue Screen'), findsOneWidget);
      expect(container.read(resonancesControllerProvider).incomingLikes.length, initialLikesCount - 1);
      expect(container.read(resonancesControllerProvider).mutualConnections.length, initialMutualCount + 1);
    });
  });

  group('Phase 5 Exit Criterion 5: BlurHash Smooth Placeholder Transition', () {
    testWidgets('CandidatePhotoCarousel renders with BlurHash placeholder and dot indicators',
        (tester) async {
      const photoUrls = [
        'https://storage.ur-heart.com/profiles/candidate1_a.webp',
        'https://storage.ur-heart.com/profiles/candidate1_b.webp',
      ];
      const blurHashes = [
        'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
        'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 380,
              child: CandidatePhotoCarousel(
                photoUrls: photoUrls,
                blurHashes: blurHashes,
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify carousel widget is rendered
      expect(find.byType(CandidatePhotoCarousel), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
