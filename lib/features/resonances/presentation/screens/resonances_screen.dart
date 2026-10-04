import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import 'package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart';
import '../widgets/incoming_like_card.dart';
import '../widgets/mutual_connection_tile.dart';
import '../widgets/unlock_resonances_banner.dart';
import '../controllers/resonances_controller.dart';
import '../../domain/resonance_models.dart';


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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resonancesControllerProvider.notifier).loadResonances();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToChat({
    required BuildContext context,
    required String matchId,
    required String recipientId,
    required String recipientName,
    String recipientAvatarUrl = '',
    bool isVerified = false,
    String bio = '',
    String location = '',
    String sharedQuote = 'Resonance established',
  }) {
    // Strip prefixes so dialogue controller and API resolve clean UUID
    String cleanId = matchId;
    for (final prefix in ['conn_', 'match-', 'match_', 'spark_']) {
      if (cleanId.startsWith(prefix)) {
        cleanId = cleanId.substring(prefix.length);
        break;
      }
    }

    Navigator.of(context).pushNamed(
      ChatDialogueScreen.routeName,
      arguments: ChatDialogueArguments(
        matchId: cleanId,
        recipientId: recipientId,
        recipientName: recipientName,
        recipientAvatarUrl: recipientAvatarUrl,
        isVerified: isVerified,
        bio: bio,
        location: location,
        sharedContextQuote: sharedQuote,
        isOnline: true,
        hasWaKey: false,
      ),
    );
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
            // Tab 1: Liked You Grid with Pull-to-Refresh
            RefreshIndicator(
              color: pine,
              onRefresh: () => ref.read(resonancesControllerProvider.notifier).loadResonances(),
              child: resonancesState.incomingLikes.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'No new resonances yet. Your presence is radiating quietly.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subText, fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        if (!resonancesState.isSovereignUser)
                          UnlockResonancesBanner(incomingCount: resonancesState.incomingLikes.length),
                        Expanded(
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
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
                              String senderId = '';
                              String sName = 'Seeker';
                              String sPhoto = '';
                              String sBio = '';
                              String sLoc = '';
                              bool sVer = false;

                              if (item is IncomingLikeProfile) {
                                senderId = item.senderId.isNotEmpty ? item.senderId : item.id;
                                sName = item.fullName;
                                sPhoto = item.photoUrl;
                                sBio = item.bio;
                                sLoc = item.location;
                                sVer = item.isVerified;
                              } else if (item is Map) {
                                senderId = (item['user_id'] as String? ?? item['sender_id'] as String? ?? item['id'] as String? ?? '');
                                sName = (item['full_name'] as String? ?? item['name'] as String? ?? 'Seeker');
                                sPhoto = (item['photo_url'] as String? ?? item['avatar_url'] as String? ?? '');
                                sBio = (item['bio'] as String? ?? '');
                                sLoc = (item['location'] as String? ?? '');
                                sVer = (item['is_verified'] as bool? ?? false);
                              }

                              return IncomingLikeCard(
                                likeData: item,
                                isDark: isDark,
                                isSovereignUser: resonancesState.isSovereignUser,
                                onChatTriggered: () async {
                                  final matchId = await ref.read(resonancesControllerProvider.notifier).createMutualMatch(senderId);
                                  if (matchId != null && context.mounted) {
                                    _navigateToChat(
                                      context: context,
                                      matchId: matchId,
                                      recipientId: senderId,
                                      recipientName: sName,
                                      recipientAvatarUrl: sPhoto,
                                      bio: sBio,
                                      location: sLoc,
                                      isVerified: sVer,
                                      sharedQuote: 'Direct Sanctuary Resonance Ignited',
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            // Tab 2: Mutual Connections with Pull-to-Refresh
            RefreshIndicator(
              color: pine,
              onRefresh: () => ref.read(resonancesControllerProvider.notifier).loadResonances(),
              child: resonancesState.mutualConnections.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'No active mutual matches yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subText, fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: resonancesState.mutualConnections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final match = resonancesState.mutualConnections[index];
                        String matchId = '';
                        String pId = '';
                        String pName = 'Sanctuary Match';
                        String pPhoto = '';
                        bool isVer = false;
                        String bio = '';
                        String loc = '';
                        String tag = 'Mutual Resonance';

                        if (match is MutualConnection) {
                          matchId = match.matchId.isNotEmpty ? match.matchId : match.id;
                          pId = match.partnerId;
                          pName = match.fullName;
                          pPhoto = match.photoUrl;
                          isVer = match.isVerified;
                          bio = match.bio;
                          loc = match.location;
                          tag = match.categoryTag;
                        } else if (match is Map) {
                          matchId = (match['match_id'] as String? ?? match['id'] as String? ?? '');
                          pId = (match['partner_id'] as String? ?? match['recipient_id'] as String? ?? '');
                          pName = (match['full_name'] as String? ?? match['name'] as String? ?? 'Sanctuary Match');
                          pPhoto = (match['photo_url'] as String? ?? match['avatar_url'] as String? ?? '');
                          isVer = (match['is_verified'] as bool? ?? false);
                          bio = (match['bio'] as String? ?? '');
                          loc = (match['location'] as String? ?? '');
                          tag = (match['category_tag'] as String? ?? 'Mutual Resonance');
                        }

                        return MutualConnectionTile(
                          match: match,
                          isDark: isDark,
                          onTap: () => _navigateToChat(
                            context: context,
                            matchId: matchId,
                            recipientId: pId,
                            recipientName: pName,
                            recipientAvatarUrl: pPhoto,
                            isVerified: isVer,
                            bio: bio,
                            location: loc,
                            sharedQuote: tag,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
