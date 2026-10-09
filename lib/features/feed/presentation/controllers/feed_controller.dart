import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/feed_repository.dart';
import '../../../growth/presentation/controllers/growth_hub_controller.dart';

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
  final Ref? _ref;

  FeedController(this._repository, [this._ref]) : super(const FeedState()) {
    loadDiscoveryFeed();
  }

  Future<void> loadDiscoveryFeed() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deck = await _repository.fetchDiscoveryDeck();
      final prefs = await SharedPreferences.getInstance();
      final cachedLetters = prefs.getInt('ur_heart_direct_letters') ?? 0;
      final serverLetters = deck.directLettersCount ?? 0;
      // Defense-in-depth: Never overwrite positive locally-cached letters with an unauthenticated 0
      final resolvedLetters = serverLetters > 0
          ? serverLetters
          : (cachedLetters > 0 ? cachedLetters : state.directLettersCount);

      if (resolvedLetters > 0) {
        await prefs.setInt('ur_heart_direct_letters', resolvedLetters);
      }

      // Client-side defense-in-depth: Orientation Shield and Strict Self-Exclusion
      final userGender = prefs.getString('profile_gender') ?? '';
      final userInterestedIn = prefs.getString('profile_interested_in') ?? 'Everyone';
      final myUserId = prefs.getString('ur_heart_user_id') ?? prefs.getString('profile_user_id') ?? '';
      final myEmail = (prefs.getString('ur_heart_user_email') ?? '').trim().toLowerCase();

      final filtered = deck.candidates.where((c) {
        // 1. Strict Self-Exclusion Shield: Caller must NEVER see their own card
        if (myUserId.isNotEmpty && (c.id == myUserId || c.id.toLowerCase().contains(myUserId.toLowerCase()))) {
          return false;
        }
        if (myEmail.isNotEmpty && c.id.toLowerCase() == myEmail) {
          return false;
        }

        // 2. Orientation Shield
        return CandidateProfile.checkOrientationShield(
          userGender: userGender,
          userInterestedIn: userInterestedIn,
          targetGender: c.gender,
          targetInterestedIn: c.lookingFor,
        );
      }).toList();

      if (!mounted) return;
      final serverSwipes = deck.swipesRemaining ?? state.swipesRemaining;
      state = state.copyWith(
        candidates: filtered,
        swipesRemaining: serverSwipes,
        directLettersCount: resolvedLetters,
        isLoading: false,
      );

      _ref?.read(growthHubControllerProvider.notifier).syncWithFeedBalances(
        swipes: serverSwipes,
        directLetters: resolvedLetters,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Alias for refresh and external callers (ACT-23)
  Future<void> loadFeed() => loadDiscoveryFeed();

  /// Prunes a candidate by ID (e.g., when a direct letter or match is formed with that user)
  void removeCandidateById(String candidateId) {
    if (state.candidates.isEmpty) return;
    final updated = state.candidates.where((c) => c.id != candidateId).toList();
    if (updated.length != state.candidates.length) {
      state = state.copyWith(candidates: updated);
    }
  }

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

    final nextSwipes = math.max(0, state.swipesRemaining - 1);
    state = state.copyWith(
      candidates: updatedCandidates,
      passedProfiles: updatedPassed,
      swipesRemaining: nextSwipes,
    );
    _ref?.read(growthHubControllerProvider.notifier).consumeSwipe();

    try {
      final result = await _repository.recordSwipe(
        targetUserId: candidate.id,
        swipeType: 'pass',
      );
      state = state.copyWith(swipesRemaining: result.swipesRemaining);
      _ref?.read(growthHubControllerProvider.notifier).syncWithFeedBalances(
        swipes: result.swipesRemaining,
      );
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

    final nextSwipes = math.max(0, state.swipesRemaining - 1);
    state = state.copyWith(
      candidates: updatedCandidates,
      swipesRemaining: nextSwipes,
    );
    _ref?.read(growthHubControllerProvider.notifier).consumeSwipe();

    try {
      final result = await _repository.recordSwipe(
        targetUserId: candidate.id,
        swipeType: 'like',
      );
      state = state.copyWith(swipesRemaining: result.swipesRemaining);
      _ref?.read(growthHubControllerProvider.notifier).syncWithFeedBalances(
        swipes: result.swipesRemaining,
      );
      return true;
    } catch (e) {
      await loadDiscoveryFeed();
      return false;
    }
  }

  /// Handles Direct Letter (Up swipe)
  Future<bool> swipeDirectLetter({String? letterText}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedLetters = prefs.getInt('ur_heart_direct_letters') ?? 0;
    final currentLetters = state.directLettersCount > 0 ? state.directLettersCount : cachedLetters;
    if (currentLetters <= 0) {
      return false;
    }
    final candidate = state.currentCandidate;
    if (candidate == null) return false;

    final updatedCandidates = List<CandidateProfile>.from(state.candidates)
      ..removeAt(0);

    final nextLetters = math.max(0, currentLetters - 1);
    final nextSwipes = math.max(0, state.swipesRemaining - 1);
    state = state.copyWith(
      candidates: updatedCandidates,
      directLettersCount: nextLetters,
      swipesRemaining: nextSwipes,
    );

    try {
      await prefs.setInt('ur_heart_direct_letters', nextLetters);
      await prefs.setInt('ur_heart_swipes_remaining', nextSwipes);
    } catch (_) {}

    _ref?.read(growthHubControllerProvider.notifier).syncWithFeedBalances(
      swipes: nextSwipes,
      directLetters: nextLetters,
    );

    try {
      final result = await _repository.recordSwipe(
        targetUserId: candidate.id,
        swipeType: 'direct',
        letterText: letterText,
      );
      final finalLetters = result.directLettersCount ?? nextLetters;
      state = state.copyWith(
        swipesRemaining: result.swipesRemaining,
        directLettersCount: finalLetters,
      );
      _ref?.read(growthHubControllerProvider.notifier).syncWithFeedBalances(
        swipes: result.swipesRemaining,
        directLetters: finalLetters,
      );
      return true;
    } catch (e) {
      await loadDiscoveryFeed();
      return false;
    }
  }

  /// Explicit setter to synchronize direct letters balance from rewards/growth hub
  void setDirectLettersCount(int count) {
    state = state.copyWith(directLettersCount: count);
    SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_direct_letters', count));
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

  /// Dispatches bilateral photo reveal request for a veiled candidate
  Future<bool> requestPhotoReveal(String candidateId) async {
    try {
      final success = await _repository.requestPhotoReveal(candidateId);
      if (success) {
        final updatedCandidates = state.candidates.map((c) {
          if (c.id == candidateId) {
            return c.copyWith(photoRevealStatus: 'pending');
          }
          return c;
        }).toList();
        state = state.copyWith(candidates: updatedCandidates);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Responds to photo reveal request ('accept' or 'decline')
  Future<bool> respondToPhotoReveal(String requesterId, String action) async {
    try {
      final success = await _repository.respondToPhotoReveal(requesterId, action);
      if (success && action == 'accept') {
        final updatedCandidates = state.candidates.map((c) {
          if (c.id == requesterId) {
            return c.copyWith(
              isPhotoUnlocked: true,
              photoRevealStatus: 'accepted',
            );
          }
          return c;
        }).toList();
        state = state.copyWith(candidates: updatedCandidates);
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  void setSwipesRemaining(int count) {
    state = state.copyWith(swipesRemaining: count);
  }

  void dismissAdModal() {
    state = state.copyWith(isOutOfSwipesModalVisible: false);
  }

  void reset() {
    state = const FeedState();
  }
}

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return FeedController(repo, ref);
});
