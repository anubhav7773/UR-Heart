import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/chat_repository.dart';

class ChatsListState {
  final List<ChatConversation> allConversations;
  final List<ChatConversation> filteredConversations;
  final List<SparkProfile> sparks;
  final String searchQuery;
  final bool isLoading;

  const ChatsListState({
    required this.allConversations,
    required this.filteredConversations,
    required this.sparks,
    this.searchQuery = '',
    this.isLoading = false,
  });

  int get totalActive => allConversations.length;

  int get directCount => allConversations
      .where((c) => c.categoryTag.toLowerCase().contains('direct'))
      .length;

  int get mutualCount => allConversations
      .where((c) => c.categoryTag.toLowerCase().contains('mutual'))
      .length;

  ChatsListState copyWith({
    List<ChatConversation>? allConversations,
    List<ChatConversation>? filteredConversations,
    List<SparkProfile>? sparks,
    String? searchQuery,
    bool? isLoading,
  }) {
    return ChatsListState(
      allConversations: allConversations ?? this.allConversations,
      filteredConversations: filteredConversations ?? this.filteredConversations,
      sparks: sparks ?? this.sparks,
      searchQuery: searchQuery ?? this.searchQuery,
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
    state = state.copyWith(
      allConversations: convs,
      filteredConversations: _filterList(convs, state.searchQuery),
      sparks: sparks,
      isLoading: false,
    );
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredConversations: _filterList(state.allConversations, query),
    );
  }

  List<ChatConversation> _filterList(List<ChatConversation> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final nameMatches = c.recipientName.toLowerCase().contains(q);
      final tagMatches = c.categoryTag.toLowerCase().contains(q);
      final textMatches = c.lastMessageText.toLowerCase().contains(q);
      return nameMatches || tagMatches || textMatches;
    }).toList();
  }
}
