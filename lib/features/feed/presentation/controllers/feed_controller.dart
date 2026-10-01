import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/feed_repository.dart';

/// Immutable state container for Sanctuary Discovery Feed
class FeedState {
  final List<CandidateProfile> candidates;
  final List<CandidateProfile> passedProfiles;
  final int swipesRemaining;
  final int directLettersCount;
  final bool isLoading;
  final bool isOutOfSwipesModalVisible;
  final String? errorMessage;

  const FeedState({
    this.candidates = const [],
    this.passedProfiles = const [],
    this.swipesRemaining = 10,
    this.directLettersCount = 0,
    this.isLoading = false,
    this.isOutOfSwipesModalVisible = false,
    this.errorMessage,
  });

  CandidateProfile? get currentCandidate =>
      candidates.isNotEmpty ? candidates.first : null;

  FeedState copyWith({
    List<CandidateProfile>? candidates,
    List<CandidateProfile>? passedProfiles,
    int? swipesRemaining,
    int? directLettersCount,
    bool? isLoading,
    bool? isOutOfSwipesModalVisible,
    String? errorMessage,
  }) {
    return FeedState(
      candidates: candidates ?? this.candidates,
      passedProfiles: passedProfiles ?? this.passedProfiles,
      swipesRemaining: swipesRemaining ?? this.swipesRemaining,
      directLettersCount: directLettersCount ?? this.directLettersCount,
      isLoading: isLoading ?? this.isLoading,
      isOutOfSwipesModalVisible:
          isOutOfSwipesModalVisible ?? this.isOutOfSwipesModalVisible,
      errorMessage: errorMessage,
    );
  }
}

/// Controller managing card swipe gestures, quota exhaustion gate, and pass stack
class FeedController extends StateNotifier<FeedState> {
  final FeedRepository _repository;

  FeedController(this._repository) : super(const FeedState()) {
    loadDiscoveryFeed();
  }

  Future<void> loadDiscoveryFeed() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deck = await _repository.fetchDiscoveryDeck();
      final prefs = await SharedPreferences.getInstance();
      final cachedLetters = prefs.getInt('ur_heart_direct_letters');
      final resolvedLetters = deck.directLettersCount ?? cachedLetters ?? state.directLettersCount;

      if (deck.directLettersCount != null) {
        await prefs.setInt('ur_heart_direct_letters', deck.directLettersCount!);
      }

      // Client-side defense-in-depth orientation filter
      final userGender = prefs.getString('profile_gender') ?? '';
      final userInterestedIn = prefs.getString('profile_interested_in') ?? 'Everyone';
      final filtered = deck.candidates.where((c) {
        return CandidateProfile.checkOrientationShield(
          userGender: userGender,
          userInterestedIn: userInterestedIn,
          targetGender: c.gender,
          targetInterestedIn: c.lookingFor,
        );
      }).toList();

      if (!mounted) return;
      state = state.copyWith(
        candidates: filtered,
        swipesRemaining: deck.swipesRemaining ?? state.swipesRemaining,
        directLettersCount: resolvedLetters,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Alias for refresh and external callers (ACT-23)
  Future<void> loadFeed() => loadDiscoveryFeed();

  /// Handles Pass swipe (Left swipe)
  Future<bool> swipePass() async {
    if (state.swipesRemaining <= 0) {
      state = state.copyWith(isOutOfSwipesModalVisible: true);
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    // Optimistic removal
    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);
    final updatedPassed = List<CandidateProfile>.from(state.passedProfiles)
      ..insert(0, candidate);

    state = state.copyWith(
      candidates: updatedCandidates,
      passedProfiles: updatedPassed,
    );

    try {
      final remaining = await _repository.recordSwipe(
        targetUserId: candidate.id,
        swipeType: 'pass',
      );
      state = state.copyWith(swipesRemaining: remaining);
      return true;
    } catch (e) {
      // Revert if error
      await loadDiscoveryFeed();
      return false;
    }
  }

  /// Handles Like swipe (Right swipe)
  Future<bool> swipeLike() async {
    if (state.swipesRemaining <= 0) {
      state = state.copyWith(isOutOfSwipesModalVisible: true);
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    // Optimistic removal
    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);

    state = state.copyWith(
      candidates: updatedCandidates,
    );

    try {
      final remaining = await _repository.recordSwipe(
        targetUserId: candidate.id,
        swipeType: 'like',
      );
      state = state.copyWith(swipesRemaining: remaining);
      return true;
    } catch (e) {
      await loadDiscoveryFeed();
      return false;
    }
  }

  /// Handles Direct Letter (Up swipe)
  Future<bool> swipeDirectLetter({String? letterText}) async {
    if (state.directLettersCount <= 0) {
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);

    state = state.copyWith(
      candidates: updatedCandidates,
      directLettersCount: state.directLettersCount - 1,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ur_heart_direct_letters', state.directLettersCount);
    } catch (_) {}

    try {
      final remaining = await _repository.recordSwipe(
        targetUserId: candidate.id,
        swipeType: 'direct',
        letterText: letterText,
      );
      state = state.copyWith(swipesRemaining: remaining);
      return true;
    } catch (e) {
      await loadDiscoveryFeed();
      return false;
    }
  }

  /// Prepend restored profile back to the top of the feed deck from Screen 6
  void prependCandidate(CandidateProfile profile) {
    final updatedCandidates = [profile, ...state.candidates];
    final updatedPassed = List<CandidateProfile>.from(state.passedProfiles)
      ..removeWhere((p) => p.id == profile.id);

    state = state.copyWith(
      candidates: updatedCandidates,
      passedProfiles: updatedPassed,
    );
  }

  /// Replenishes swipes when user watches a 10s rewarded reflection ad
  void replenishSwipes(int count) {
    state = state.copyWith(
      swipesRemaining: state.swipesRemaining + count,
      isOutOfSwipesModalVisible: false,
    );
  }

  void setSwipesRemaining(int count) {
    state = state.copyWith(swipesRemaining: count);
  }

  void dismissAdModal() {
    state = state.copyWith(isOutOfSwipesModalVisible: false);
  }
}

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return FeedController(repo);
});
