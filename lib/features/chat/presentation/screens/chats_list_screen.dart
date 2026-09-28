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
/// Real-time message stream hub with active conversation metrics and sparks carousel
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
                      _buildEmptyState(titleColor, mutedColor)
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

  Widget _buildEmptyState(Color titleColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 44.0, color: mutedColor),
            const SizedBox(height: 12.0),
            Text(
              'No dialogues match your search',
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Try adjusting your search query or explore recent sparks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}
