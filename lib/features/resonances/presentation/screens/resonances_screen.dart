import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../widgets/incoming_like_card.dart';
import '../widgets/mutual_connection_tile.dart';
import '../widgets/unlock_resonances_banner.dart';
import '../controllers/resonances_controller.dart';

class ResonancesScreen extends ConsumerStatefulWidget {
  const ResonancesScreen({super.key});

  static const String routeName = '/resonances';

  @override
  ConsumerState<ResonancesScreen> createState() => _ResonancesScreenState();
}

class _ResonancesScreenState extends ConsumerState<ResonancesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToChat(BuildContext context, String matchId) {
    Navigator.of(context).pushNamed('/chat-dialogue', arguments: {'match_id': matchId});
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final resonancesState = ref.watch(resonancesControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Resonances',
          style: TextStyle(fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold, color: primaryText),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: pine,
          indicatorWeight: 2.5,
          labelColor: primaryText,
          unselectedLabelColor: subText,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: 'Liked You (${resonancesState.incomingLikes.length})'),
            Tab(text: 'Mutual (${resonancesState.mutualConnections.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Liked You Grid
            resonancesState.incomingLikes.isEmpty
                ? Center(child: Text('No new resonances yet. Your presence is radiating quietly.', style: TextStyle(color: subText)))
                : Column(
                    children: [
                      if (!resonancesState.isSovereignUser)
                        UnlockResonancesBanner(incomingCount: resonancesState.incomingLikes.length),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: resonancesState.incomingLikes.length,
                          itemBuilder: (context, index) {
                            final item = resonancesState.incomingLikes[index];
                            final senderId = item is Map
                                ? (item['user_id'] as String? ?? item['id'] as String? ?? '')
                                : (item.senderId as String? ?? item.id as String? ?? '');

                            return IncomingLikeCard(
                              likeData: item,
                              isDark: isDark,
                              isSovereignUser: resonancesState.isSovereignUser,
                              onChatTriggered: () async {
                                final matchId = await ref.read(resonancesControllerProvider.notifier).createMutualMatch(senderId);
                                if (matchId != null && context.mounted) {
                                  _navigateToChat(context, matchId);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
            // Tab 2: Mutual Connections
            resonancesState.mutualConnections.isEmpty
                ? Center(child: Text('No active mutual matches yet.', style: TextStyle(color: subText)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: resonancesState.mutualConnections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final match = resonancesState.mutualConnections[index];
                      final matchId = match is Map
                          ? (match['id'] as String? ?? '')
                          : (match.matchId as String? ?? match.id as String? ?? '');

                      return MutualConnectionTile(
                        match: match,
                        isDark: isDark,
                        onTap: () => _navigateToChat(context, matchId),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
