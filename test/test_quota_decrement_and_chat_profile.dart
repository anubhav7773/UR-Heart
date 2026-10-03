import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/media/sanctuary_image_resolver.dart';
import 'package:ur_heart/features/feed/presentation/controllers/feed_controller.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';


class FakeFeedRepository implements FeedRepository {
  int serverDirectLetters;
  int serverSwipesRemaining;

  FakeFeedRepository({
    this.serverDirectLetters = 1,
    this.serverSwipesRemaining = 10,
  });

  @override
  Future<DiscoveryDeckResponse> fetchDiscoveryDeck({int limit = 20, String? cursor}) async {
    return DiscoveryDeckResponse(
      candidates: [
        const CandidateProfile(
          id: 'candidate-1',
          fullName: 'Priya',
          age: 24,
          gender: 'Female',
          lookingFor: 'Everyone',
          locationName: 'Delhi',
          distanceKm: 5.0,
          resonanceScore: 90,
          intentQuote: 'Mindful presence',
          interests: ['Art'],
          avatarUrl: 'https://urheart.app/p.jpg',
          photoUrls: [],
          blurHashes: [],
        ),
      ],
      swipesRemaining: serverSwipesRemaining,
      directLettersCount: serverDirectLetters,
    );
  }

  @override
  Future<List<CandidateProfile>> getDiscoveryFeed({int limit = 20, String? cursor}) async {
    final deck = await fetchDiscoveryDeck(limit: limit, cursor: cursor);
    return deck.candidates;
  }

  @override
  Future<SwipeResult> recordSwipe({
    required String targetUserId,
    required String swipeType,
    String? letterText,
  }) async {
    if (swipeType == 'direct' && serverDirectLetters > 0) {
      serverDirectLetters--;
    }
    return SwipeResult(
      swipesRemaining: serverSwipesRemaining,
      directLettersCount: serverDirectLetters,
    );
  }

  @override
  Future<bool> restorePassedProfile(String targetUserId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProfileRepository implements ProfileRepository {
  int serverRevealTokens;
  int serverDirectLetters;

  FakeProfileRepository({
    this.serverRevealTokens = 0,
    this.serverDirectLetters = 0,
  });

  @override
  Future<UserProfile> fetchMyProfile() async {
    return UserProfile(
      id: 'my-user-id',
      fullName: 'Anubhav',
      email: 'user@urheart.app',
      age: 26,
      dobVerificationPill: '1998-05-15',
      gender: 'Male',
      interestedIn: 'Female',
      maskedWhatsApp: '+91 98765 43210',
      memberSinceText: 'Member of Sanctuary',
      hasVerifiedCrest: true,
      location: 'Lucknow',
      bio: 'Mindful architecture',
      profession: 'Architect',
      education: 'B.Tech',
      minAgePref: 20,
      maxAgePref: 30,
      avatarUrl: 'https://urheart.app/my_avatar.jpg',
      momentPhotos: [],
      swipesRemaining: 15,
      directLettersCount: serverDirectLetters,
      revealTokensCount: serverRevealTokens,
      streakCount: 3,
      boostPoints: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ur_heart_direct_letters': 1,
      'ur_heart_reveal_tokens': 2,
    });
  });

  group('Problem 2 Fix: Direct Letters & Reveal Tokens Decrement', () {
    test('FeedController.swipeDirectLetter decrements count and persists 0 without resurrecting', () async {
      final fakeRepo = FakeFeedRepository(serverDirectLetters: 1);
      final controller = FeedController(fakeRepo);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.state.directLettersCount, 1);


      // Perform direct letter swipe
      final ok = await controller.swipeDirectLetter(letterText: 'Hello intentional friend');
      expect(ok, isTrue);
      expect(controller.state.directLettersCount, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ur_heart_direct_letters'), 0);

      // Reload discovery feed from server when count is 0
      fakeRepo.serverDirectLetters = 0;
      await controller.loadDiscoveryFeed();
      expect(controller.state.directLettersCount, 0);
      expect(prefs.getInt('ur_heart_direct_letters'), 0);
    });

    test('GrowthHubController.syncUserData properly decrements revealTokensCount and removes math.max latch', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ur_heart_reveal_tokens', 2);
      await prefs.setInt('ur_heart_direct_letters', 1);

      // Server now has 0 reveal tokens (user spent them) and 0 direct letters
      final fakeProfileRepo = FakeProfileRepository(serverRevealTokens: 0, serverDirectLetters: 0);
      final growthController = GrowthHubController(fakeProfileRepo, null);

      await growthController.syncUserData();

      // Must NOT be stuck at 2! Must be ground-truth server value 0
      expect(growthController.state.revealTokensCount, 0);
      expect(growthController.state.directLetters, 0);
      expect(prefs.getInt('ur_heart_reveal_tokens'), 0);
      expect(prefs.getInt('ur_heart_direct_letters'), 0);
    });

    test('GrowthHubController.updateRevealTokens updates state and SharedPreferences immediately', () async {
      final fakeProfileRepo = FakeProfileRepository(serverRevealTokens: 1);
      final growthController = GrowthHubController(fakeProfileRepo, null);

      growthController.updateRevealTokens(0);
      expect(growthController.state.revealTokensCount, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ur_heart_reveal_tokens'), 0);
    });
  });

  group('Problem 3 Fix: Image Resolver Supports Both Network & Local File Avatars', () {
    test('resolveSanctuaryImageProvider resolves network URLs', () {
      final provider = resolveSanctuaryImageProvider('https://urheart.app/media/avatar.webp');
      expect(provider, isA<NetworkImage>());
    });

    test('resolveSanctuaryImageProvider handles empty or null safely', () {
      expect(resolveSanctuaryImageProvider(null), isNull);
      expect(resolveSanctuaryImageProvider(''), isNull);
      expect(resolveSanctuaryImageProvider('   '), isNull);
      expect(hasValidSanctuaryImage(''), isFalse);
    });

    test('resolveSanctuaryImageProvider resolves local file images if file exists', () {
      final tempDir = Directory.systemTemp.createTempSync('sanctuary_test');
      final tempFile = File('${tempDir.path}/test_avatar.jpg')..writeAsStringSync('dummy_image_data');

      final provider = resolveSanctuaryImageProvider(tempFile.path);
      expect(provider, isA<FileImage>());
      expect(hasValidSanctuaryImage(tempFile.path), isTrue);

      tempDir.deleteSync(recursive: true);
    });
  });
}
