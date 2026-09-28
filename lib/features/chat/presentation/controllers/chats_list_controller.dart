import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/chat_repository.dart';

class ChatsListState {
  final List<ChatConversation> allConversations;
  final List<ChatConversation> filteredConversations;
  final List<SparkProfile> sparks;
  final String searchQuery;
  final String activeFilter; // 'all', 'unread', 'direct', 'mutual'
  final bool isLoading;

  const ChatsListState({
    required this.allConversations,
    required this.filteredConversations,
    required this.sparks,
    this.searchQuery = '',
    this.activeFilter = 'all',
    this.isLoading = false,
  });

  int get totalActive => allConversations.length;

  int get directCount => allConversations
      .where((c) => c.categoryTag.toLowerCase().contains('direct'))
      .length;

  int get mutualCount => allConversations
      .where((c) => c.categoryTag.toLowerCase().contains('mutual'))
      .length;

  int get unreadTotalCount => allConversations
      .where((c) => c.unreadCount > 0)
      .length;

  ChatsListState copyWith({
    List<ChatConversation>? allConversations,
    List<ChatConversation>? filteredConversations,
    List<SparkProfile>? sparks,
    String? searchQuery,
    String? activeFilter,
    bool? isLoading,
  }) {
    return ChatsListState(
      allConversations: allConversations ?? this.allConversations,
      filteredConversations: filteredConversations ?? this.filteredConversations,
      sparks: sparks ?? this.sparks,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final chatsListControllerProvider =
    StateNotifierProvider<ChatsListController, ChatsListState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatsListController(repo);
});

class ChatsListController extends StateNotifier<ChatsListState> {
  final ChatRepository _repo;

  ChatsListController(this._repo)
      : super(const ChatsListState(
          allConversations: [],
          filteredConversations: [],
          sparks: [],
          isLoading: true,
        )) {
    loadHubData();
  }

  Future<void> loadHubData() async {
    state = state.copyWith(isLoading: true);
    final convs = await _repo.getConversations();
    final sparks = await _repo.getRecentSparks();

    final prefs = await SharedPreferences.getInstance();
    final blockedIds = (prefs.getStringList('ur_heart_blocked_user_ids') ?? []).toSet();
    final activeConvs = convs.where((c) => !blockedIds.contains(c.recipientId) && !blockedIds.contains(c.matchId)).toList();
    final activeSparks = sparks.where((s) => !blockedIds.contains(s.id)).toList();

    state = state.copyWith(
      allConversations: activeConvs,
      filteredConversations: _filterList(activeConvs, state.searchQuery, state.activeFilter),
      sparks: activeSparks,
      isLoading: false,
    );
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredConversations: _filterList(state.allConversations, query, state.activeFilter),
    );
  }

  void setActiveFilter(String filter) {
    state = state.copyWith(
      activeFilter: filter,
      filteredConversations: _filterList(state.allConversations, state.searchQuery, filter),
    );
  }

  List<ChatConversation> _filterList(List<ChatConversation> list, String query, String filter) {
    var result = list;

    // Apply category / status filter
    if (filter == 'unread') {
      result = result.where((c) => c.unreadCount > 0).toList();
    } else if (filter == 'direct') {
      result = result.where((c) => c.categoryTag.toLowerCase().contains('direct')).toList();
    } else if (filter == 'mutual') {
      result = result.where((c) => c.categoryTag.toLowerCase().contains('mutual')).toList();
    }

    // Apply text search filter
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((c) {
        final nameMatches = c.recipientName.toLowerCase().contains(q);
        final tagMatches = c.categoryTag.toLowerCase().contains(q);
        final textMatches = c.lastMessageText.toLowerCase().contains(q);
        return nameMatches || tagMatches || textMatches;
      }).toList();
    }

    return result;
  }
}
