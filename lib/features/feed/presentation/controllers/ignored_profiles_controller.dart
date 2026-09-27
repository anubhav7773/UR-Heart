import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/feed_repository.dart';
import 'feed_controller.dart';

class IgnoredProfilesState {
  final List<dynamic> passedProfiles;
  final bool isLoading;
  final String? restoringId;

  const IgnoredProfilesState({
    this.passedProfiles = const [],
    this.isLoading = false,
    this.restoringId,
  });

  IgnoredProfilesState copyWith({
    List<dynamic>? passedProfiles,
    bool? isLoading,
    String? restoringId,
  }) {
    return IgnoredProfilesState(
      passedProfiles: passedProfiles ?? this.passedProfiles,
      isLoading: isLoading ?? this.isLoading,
      restoringId: restoringId,
    );
  }
}

class IgnoredProfilesController extends StateNotifier<IgnoredProfilesState> {
  final FeedRepository _repository;
  final Ref _ref;

  IgnoredProfilesController(this._repository, this._ref)
      : super(const IgnoredProfilesState()) {
    syncFromFeedController();
  }

  void syncFromFeedController() {
    final feedPassed = _ref.read(feedControllerProvider).passedProfiles;
    state = state.copyWith(passedProfiles: feedPassed);
  }

  /// Revisit action: restores profile back to discovery deck via DELETE /api/v1/swipes/pass/{target_id}
  Future<bool> revisitProfile(dynamic profileOrId) async {
    final String targetId = profileOrId is String
        ? profileOrId
        : (profileOrId is Map ? (profileOrId['id'] as String? ?? '') : (profileOrId.id as String? ?? ''));

    state = state.copyWith(restoringId: targetId);

    // Call DELETE /api/v1/swipes/pass/{target_id}
    await _repository.restorePassedProfile(targetId);

    // Find candidate object if available
    dynamic foundProfile;
    final updatedList = List<dynamic>.from(state.passedProfiles)..removeWhere((p) {
      final pid = p is Map ? p['id'] : (p is CandidateProfile ? p.id : p.toString());
      if (pid == targetId) {
        foundProfile = p;
        return true;
      }
      return false;
    });

    // If candidate found in passed, prepend to FeedController
    if (foundProfile != null) {
      if (foundProfile is CandidateProfile) {
        _ref.read(feedControllerProvider.notifier).prependCandidate(foundProfile as CandidateProfile);
      } else if (foundProfile is Map<String, dynamic>) {
        final cand = CandidateProfile(
          id: targetId,
          fullName: foundProfile['full_name'] as String? ?? 'Sanctuary Member',
          age: foundProfile['age'] as int? ?? 24,
          gender: foundProfile['gender'] as String? ?? 'Presence',
          lookingFor: foundProfile['looking_for'] as String? ?? 'Everyone',
          locationName: foundProfile['location_name'] as String? ?? 'Ayodhya',
          distanceKm: (foundProfile['distance_km'] as num?)?.toDouble() ?? 1.5,
          resonanceScore: foundProfile['resonance_score'] as int? ?? 94,
          intentQuote: foundProfile['intent_quote'] as String? ?? '',
          interests: (foundProfile['interests'] as List<dynamic>?)?.cast<String>() ?? [],
          photoUrls: (foundProfile['photo_urls'] as List<dynamic>?)?.cast<String>() ?? [],
          blurHashes: (foundProfile['blur_hashes'] as List<dynamic>?)?.cast<String>() ?? [],
        );
        _ref.read(feedControllerProvider.notifier).prependCandidate(cand);
      }
    }

    state = state.copyWith(
      passedProfiles: updatedList,
      restoringId: null,
    );
    return true;
  }
}

final ignoredProfilesControllerProvider = StateNotifierProvider<
    IgnoredProfilesController, IgnoredProfilesState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return IgnoredProfilesController(repo, ref);
});
