import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/resonances_repository.dart';

/// State for Screen 7 Resonances & Mutual Connections
class ResonancesState {
  final int activeTab; // 0: Liked You, 1: Mutual Connections
  final List<dynamic> incomingLikes;
  final List<dynamic> mutualConnections;
  final bool isLoading;
  final bool isSovereignUser;
  final String? creatingMatchId;

  const ResonancesState({
    this.activeTab = 0,
    this.incomingLikes = const [],
    this.mutualConnections = const [],
    this.isLoading = false,
    this.isSovereignUser = false,
    this.creatingMatchId,
  });

  ResonancesState copyWith({
    int? activeTab,
    List<dynamic>? incomingLikes,
    List<dynamic>? mutualConnections,
    bool? isLoading,
    bool? isSovereignUser,
    String? creatingMatchId,
  }) {
    return ResonancesState(
      activeTab: activeTab ?? this.activeTab,
      incomingLikes: incomingLikes ?? this.incomingLikes,
      mutualConnections: mutualConnections ?? this.mutualConnections,
      isLoading: isLoading ?? this.isLoading,
      isSovereignUser: isSovereignUser ?? this.isSovereignUser,
      creatingMatchId: creatingMatchId,
    );
  }
}

/// Controller managing incoming likes, mutual match conversion, and tab selection
class ResonancesController extends StateNotifier<ResonancesState> {
  final ResonancesRepository _repository;

  ResonancesController(this._repository) : super(const ResonancesState()) {
    loadResonances();
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTab: index);
  }

  void setSovereignUser(bool isSovereign) {
    state = state.copyWith(isSovereignUser: isSovereign);
  }

  Future<void> loadResonances() async {
    state = state.copyWith(isLoading: true);
    final likes = await _repository.fetchIncomingLikes();
    final connections = await _repository.fetchMutualConnections();
    state = state.copyWith(
      incomingLikes: likes,
      mutualConnections: connections,
      isLoading: false,
    );
  }

  /// Converts incoming like to mutual match upon "💬 Chat" CTA tap
  Future<String?> createMutualMatch(String senderId) async {
    state = state.copyWith(creatingMatchId: senderId);
    try {
      final matchIdResult = await _repository.createMutualMatch(senderId);

      if (matchIdResult.isNotEmpty) {
        final updatedLikes = List<dynamic>.from(state.incomingLikes)..removeWhere((l) {
          final id = l is Map ? (l['user_id'] ?? l['sender_id'] ?? l['id']) : (l.senderId ?? l.id);
          return id == senderId;
        });

        final matchId = matchIdResult;
        final newConnection = MutualConnection(
        id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
        matchId: matchId,
        partnerId: senderId,
        fullName: 'Sanctuary Match',
        age: 24,
        photoUrl: '',
        blurHash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
        matchedTime: 'Just now',
        lastSnippet: 'Mutual resonance established.',
        hasUnreadMessages: false,
        isOnline: true,
      );

      final updatedConnections = [newConnection, ...state.mutualConnections];

        state = state.copyWith(
          incomingLikes: updatedLikes,
          mutualConnections: updatedConnections,
          creatingMatchId: null,
        );
        return matchId;
      }
    } catch (_) {
      state = state.copyWith(creatingMatchId: null);
      return null;
    }

    state = state.copyWith(creatingMatchId: null);
    return null;
  }

  Future<bool> acceptLikeAndStartChat(dynamic like) async {
    final String senderId = like is Map
        ? (like['user_id'] as String? ?? like['id'] as String? ?? '')
        : (like.senderId as String? ?? like.id as String? ?? '');
    final matchId = await createMutualMatch(senderId);
    return matchId != null;
  }
}

final resonancesControllerProvider =
    StateNotifierProvider<ResonancesController, ResonancesState>((ref) {
  final repo = ref.watch(resonancesRepositoryProvider);
  return ResonancesController(repo);
});
