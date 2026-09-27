import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../controllers/feed_controller.dart';
import '../widgets/candidate_profile_card.dart';
import '../widgets/feed_floating_action_bar.dart';
import '../widgets/out_of_swipes_ad_modal.dart';

/// Screen 05: Sanctuary Discovery Feed Scaffold
/// Features 60fps drag physics, reciprocal orientation filtering, and quota gate
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  static const String routeName = '/feed';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedControllerProvider);
    final feedNotifier = ref.read(feedControllerProvider.notifier);
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    final current = feedState.currentCandidate;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: Icon(Icons.favorite_rounded, color: pine, size: 24.0),
        ),
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5.0),
          decoration: BoxDecoration(
            color: isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 13.0, color: pine),
              const SizedBox(width: 6.0),
              Text(
                '${feedState.swipesRemaining} Skips Remaining',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_edu, color: primaryText),
            tooltip: 'Pass Vault',
            onPressed: () => Navigator.of(context).pushNamed('/ignored'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: feedState.isLoading
                  ? Center(child: CircularProgressIndicator(color: pine))
                  : current != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: CandidateProfileCard(
                            key: ValueKey(current.id),
                            candidate: current.toMap(),
                            isDark: isDark,
                            onSwipeCompleted: (swipeType) async {
                              bool ok = false;
                              if (swipeType == 'like') {
                                ok = await feedNotifier.swipeLike();
                              } else {
                                ok = await feedNotifier.swipePass();
                              }
                              if (!ok && context.mounted) {
                                _showOutOfSwipes(context);
                              }
                            },
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.spa_outlined, size: 48.0, color: pine),
                                const SizedBox(height: 14.0),
                                Text(
                                  'Sanctuary is Peaceful',
                                  style: TextStyle(
                                    fontFamily: 'Serif',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  'You have reviewed all available resonances for now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: subText),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
            if (current != null)
              FeedFloatingActionBar(
                isDark: isDark,
                onPass: () async {
                  final ok = await feedNotifier.swipePass();
                  if (!ok && context.mounted) {
                    _showOutOfSwipes(context);
                  }
                },
                onResonate: () => feedNotifier.swipeDirectLetter(),
                onLike: () async {
                  final ok = await feedNotifier.swipeLike();
                  if (!ok && context.mounted) {
                    _showOutOfSwipes(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showOutOfSwipes(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const OutOfSwipesAdModal(),
    );
  }
}
