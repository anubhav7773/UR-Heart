import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/chats_list_controller.dart';
import '../widgets/chats_metric_pill.dart';
import '../widgets/chats_search_bar.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/recent_sparks_carousel.dart';
import 'chat_dialogue_screen.dart';

/// Screen 8: Chats Hub & Recent Sparks Scaffold
/// Real-time message stream hub with active conversation metrics, sparks carousel,
/// and responsive filter controls (All, Unread, Direct Letters, Mutual Sparks).
class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  static const String routeName = '/chats';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatsListControllerProvider);
    final notifier = ref.read(chatsListControllerProvider.notifier);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Mindful Dialogues',
          style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 20.0),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              state.activeFilter == 'all' ? Icons.filter_list_rounded : Icons.filter_alt,
              color: state.activeFilter == 'all' ? mutedColor : accentColor,
              size: 22,
            ),
            tooltip: 'Filter Dialogues',
            initialValue: state.activeFilter,
            onSelected: (filter) => notifier.setActiveFilter(filter),
            color: isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder,
              ),
            ),
            itemBuilder: (context) => [
              _buildFilterMenuItem('all', 'All Conversations', Icons.all_inbox_rounded, state.activeFilter == 'all', titleColor, accentColor),
              _buildFilterMenuItem('unread', 'Unread Only (${state.unreadTotalCount})', Icons.mark_chat_unread_outlined, state.activeFilter == 'unread', titleColor, accentColor),
              _buildFilterMenuItem('direct', 'Direct Letters (${state.directCount})', Icons.mail_outline_rounded, state.activeFilter == 'direct', titleColor, accentColor),
              _buildFilterMenuItem('mutual', 'Mutual Sparks (${state.mutualCount})', Icons.favorite_border_rounded, state.activeFilter == 'mutual', titleColor, accentColor),
              _buildFilterMenuItem('past', 'Past Reflections (${state.pastCount}) 🍃', Icons.spa_outlined, state.activeFilter == 'past', titleColor, accentColor),
            ],
          ),
          IconButton(
            icon: Icon(Icons.masks_outlined, color: accentColor, size: 22),
            tooltip: 'Sanctuary Blind Date',
            onPressed: () => Navigator.of(context).pushNamed('/blind-date'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: state.isLoading
            ? Center(child: CircularProgressIndicator(color: accentColor))
            : RefreshIndicator(
                onRefresh: notifier.loadHubData,
                color: accentColor,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ChatsSearchBar(
                      isDark: isDark,
                      onChanged: notifier.updateSearchQuery,
                      onFilterTap: () => _showFilterSheet(context, state.activeFilter, notifier, isDark, accentColor, titleColor, mutedColor),
                    ),
                    if (state.activeFilter != 'all')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accentColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Filtering: ${_filterLabel(state.activeFilter)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => notifier.setActiveFilter('all'),
                                    child: Icon(Icons.close, size: 14, color: accentColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ChatsMetricPill(
                      totalActive: state.totalActive,
                      directCount: state.directCount,
                      mutualCount: state.mutualCount,
                      isDark: isDark,
                    ),
                    RecentSparksCarousel(
                      sparks: state.sparks,
                      isDark: isDark,
                      onSparkTap: (spark) {
                        Navigator.of(context).pushNamed(
                          ChatDialogueScreen.routeName,
                          arguments: ChatDialogueArguments(
                            matchId: 'match-${spark.id}',
                            recipientId: spark.id,
                            recipientName: spark.name,
                            recipientAge: spark.age,
                            recipientAvatarUrl: spark.avatarUrl,
                            isVerified: spark.isVerified,
                            bio: spark.bio,
                            location: spark.location,
                            gender: spark.gender,
                            interests: spark.interests,
                            isOnline: spark.isOnline,
                            hasWaKey: false,
                            sharedContextQuote: 'A resonance spark ignited from discovery feed.',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                      child: Text(
                        'Active Dialogues',
                        style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 16.0),
                      ),
                    ),
                    if (state.filteredConversations.isEmpty)
                      _buildEmptyState(titleColor, mutedColor, state.activeFilter != 'all')
                    else
                      ...state.filteredConversations.map(
                        (conv) => ConversationTile(
                          conversation: conv,
                          isDark: isDark,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              ChatDialogueScreen.routeName,
                              arguments: ChatDialogueArguments(
                                matchId: conv.matchId,
                                recipientId: conv.recipientId,
                                recipientName: conv.recipientName,
                                recipientAge: conv.recipientAge,
                                recipientAvatarUrl: conv.recipientAvatarUrl,
                                isVerified: conv.isVerified,
                                bio: conv.bio,
                                location: conv.location,
                                gender: conv.gender,
                                interests: conv.interests,
                                isOnline: conv.isOnline,
                                hasWaKey: conv.hasWaKey,
                                sharedContextQuote: conv.sharedContextQuote,
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(
    String value,
    String label,
    IconData icon,
    bool isSelected,
    Color titleColor,
    Color accentColor,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? accentColor : titleColor.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? accentColor : titleColor,
              ),
            ),
          ),
          if (isSelected) Icon(Icons.check, size: 16, color: accentColor),
        ],
      ),
    );
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'unread':
        return 'Unread Messages';
      case 'direct':
        return 'Direct Letters';
      case 'mutual':
        return 'Mutual Sparks';
      case 'past':
        return 'Past Reflections 🍃';
      default:
        return 'All';
    }
  }

  void _showFilterSheet(
    BuildContext context,
    String currentFilter,
    ChatsListController notifier,
    bool isDark,
    Color accentColor,
    Color titleColor,
    Color mutedColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Conversations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
              ),
              const SizedBox(height: 12),
              _buildSheetOption(sheetContext, 'all', 'All Conversations', Icons.all_inbox_rounded, currentFilter == 'all', notifier, accentColor, titleColor),
              _buildSheetOption(sheetContext, 'unread', 'Unread Only', Icons.mark_chat_unread_outlined, currentFilter == 'unread', notifier, accentColor, titleColor),
              _buildSheetOption(sheetContext, 'direct', 'Direct Letters', Icons.mail_outline_rounded, currentFilter == 'direct', notifier, accentColor, titleColor),
              _buildSheetOption(sheetContext, 'mutual', 'Mutual Sparks', Icons.favorite_border_rounded, currentFilter == 'mutual', notifier, accentColor, titleColor),
              _buildSheetOption(sheetContext, 'past', 'Past Reflections 🍃', Icons.spa_outlined, currentFilter == 'past', notifier, accentColor, titleColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    bool isSelected,
    ChatsListController notifier,
    Color accentColor,
    Color titleColor,
  ) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? accentColor : titleColor.withOpacity(0.7)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? accentColor : titleColor,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: accentColor) : null,
      onTap: () {
        notifier.setActiveFilter(value);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildEmptyState(Color titleColor, Color mutedColor, bool hasActiveFilter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 44.0, color: mutedColor),
            const SizedBox(height: 12.0),
            Text(
              hasActiveFilter ? 'No dialogues match this filter' : 'No dialogues match your search',
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4.0),
            Text(
              hasActiveFilter ? 'Try clearing your filter to view all dialogues.' : 'Try adjusting your search query or explore recent sparks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}
