import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';
import 'package:ur_heart/features/feed/presentation/controllers/feed_controller.dart';

class MockSelfFeedRepository implements FeedRepository {
  final List<CandidateProfile> mockCandidates;

  MockSelfFeedRepository(this.mockCandidates);

  @override
  int? get lastSwipesRemaining => 10;

  @override
  int? get lastDirectLettersCount => 2;

  @override
  Future<DiscoveryDeckResponse> fetchDiscoveryDeck({int limit = 20, String? cursor}) async {
    return DiscoveryDeckResponse(
      candidates: mockCandidates,
      swipesRemaining: 10,
      directLettersCount: 2,
    );
  }

  @override
  Future<List<CandidateProfile>> getDiscoveryFeed({int limit = 20, String? cursor}) async {
    return mockCandidates;
  }

  @override
  Future<SwipeResult> recordSwipe({
    required String targetUserId,
    required String swipeType,
    String? letterText,
  }) async {
    return const SwipeResult(swipesRemaining: 9, isMatch: false);
  }

  @override
  Future<bool> restorePassedProfile(String targetUserId) async => true;

  @override
  Future<List<dynamic>> getPassedProfiles() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ur_heart_user_id': 'user_self_12345',
      'profile_user_id': 'user_self_12345',
      'ur_heart_user_email': 'myself@urheart.app',
      'profile_gender': 'Man',
      'profile_interested_in': 'Women',
    });
  });

  test('FeedController strictly filters out caller self-profile by user ID and email', () async {
    const candidateOther = CandidateProfile(
      id: 'candidate_real_other',
      fullName: 'Tara Sharma',
      age: 23,
      gender: 'Woman',
      lookingFor: 'Men',
      locationName: 'Ayodhya',
      distanceKm: 2.1,
      resonanceScore: 94,
      intentQuote: 'Mindful presence and quiet walks.',
      interests: ['Poetry', 'Tea'],
      avatarUrl: 'https://images.unsplash.com/photo-1.jpg',
      photoUrls: ['https://images.unsplash.com/photo-1.jpg'],
      blurHashes: ['L6PZfSi_.AyE_3t7t7R**0o#DgR4'],
    );

    const candidateSelfById = CandidateProfile(
      id: 'user_self_12345',
      fullName: 'My Self Name',
      age: 26,
      gender: 'Woman',
      lookingFor: 'Men',
      locationName: 'Ayodhya',
      distanceKm: 0.1,
      resonanceScore: 99,
      intentQuote: 'My own profile',
      interests: ['Reading'],
      avatarUrl: 'https://images.unsplash.com/photo-self.jpg',
      photoUrls: [],
      blurHashes: [],
    );

    const candidateSelfByEmail = CandidateProfile(
      id: 'myself@urheart.app',
      fullName: 'My Self Alt',
      age: 26,
      gender: 'Woman',
      lookingFor: 'Men',
      locationName: 'Ayodhya',
      distanceKm: 0.1,
      resonanceScore: 99,
      intentQuote: 'My own profile by email',
      interests: ['Reading'],
      avatarUrl: '',
      photoUrls: [],
      blurHashes: [],
    );

    final mockRepo = MockSelfFeedRepository([
      candidateOther,
      candidateSelfById,
      candidateSelfByEmail,
    ]);

    final controller = FeedController(mockRepo);

    // Initial load occurs in constructor
    await controller.loadDiscoveryFeed();

    // Verify self profiles are strictly absent from state.candidates
    final candidateIds = controller.state.candidates.map((c) => c.id).toList();

    expect(candidateIds, contains('candidate_real_other'));
    expect(candidateIds, isNot(contains('user_self_12345')));
    expect(candidateIds, isNot(contains('myself@urheart.app')));
    expect(controller.state.candidates.length, 1);
  });
}
