import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/feed_repository.dart';

/// Immutable state container for Sanctuary Discovery Feed
class FeedState {
  final List<CandidateProfile> candidates;
  final List<CandidateProfile> passedProfiles;
  final int swipesRemaining;
  final int directLettersCount;
  final bool isLoading;
  final bool isOutOfSwipesModalVisible;

  const FeedState({
    this.candidates = const [],
    this.passedProfiles = const [],
    this.swipesRemaining = 25,
    this.directLettersCount = 1,
    this.isLoading = false,
    this.isOutOfSwipesModalVisible = false,
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
  }) {
    return FeedState(
      candidates: candidates ?? this.candidates,
      passedProfiles: passedProfiles ?? this.passedProfiles,
      swipesRemaining: swipesRemaining ?? this.swipesRemaining,
      directLettersCount: directLettersCount ?? this.directLettersCount,
      isLoading: isLoading ?? this.isLoading,
      isOutOfSwipesModalVisible:
          isOutOfSwipesModalVisible ?? this.isOutOfSwipesModalVisible,
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
    state = state.copyWith(isLoading: true);
    final profiles = await _repository.getDiscoveryFeed();
    state = state.copyWith(candidates: profiles, isLoading: false);
  }

  /// Handles Pass swipe (Left swipe)
  Future<bool> swipePass() async {
    if (state.swipesRemaining <= 0) {
      state = state.copyWith(isOutOfSwipesModalVisible: true);
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    await _repository.recordSwipe(targetId: candidate.id, swipeType: 'pass');

    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);
    final updatedPassed = List<CandidateProfile>.from(state.passedProfiles)
      ..insert(0, candidate);

    state = state.copyWith(
      candidates: updatedCandidates,
      passedProfiles: updatedPassed,
      swipesRemaining: state.swipesRemaining - 1,
    );
    return true;
  }

  /// Handles Like swipe (Right swipe)
  Future<bool> swipeLike() async {
    if (state.swipesRemaining <= 0) {
      state = state.copyWith(isOutOfSwipesModalVisible: true);
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    await _repository.recordSwipe(targetId: candidate.id, swipeType: 'like');

    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);

    state = state.copyWith(
      candidates: updatedCandidates,
      swipesRemaining: state.swipesRemaining - 1,
    );
    return true;
  }

  /// Handles Direct Letter (Up swipe)
  Future<bool> swipeDirectLetter() async {
    if (state.directLettersCount <= 0) {
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    await _repository.recordSwipe(targetId: candidate.id, swipeType: 'superlike');

    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);

    state = state.copyWith(
      candidates: updatedCandidates,
      directLettersCount: state.directLettersCount - 1,
    );
    return true;
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
