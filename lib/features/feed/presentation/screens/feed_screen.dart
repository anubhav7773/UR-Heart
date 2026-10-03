import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../controllers/feed_controller.dart';
import '../../domain/candidate_profile.dart';
import '../widgets/candidate_profile_card.dart';
import '../widgets/feed_floating_action_bar.dart';
import '../widgets/out_of_swipes_ad_modal.dart';
import '../../../growth/presentation/controllers/growth_hub_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/sanctuary_navigation_shell.dart';

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
          Consumer(
            builder: (context, ref, _) {
              final growthState = ref.watch(growthHubControllerProvider);
              final streak = growthState.streakCount;
              final isSecured = growthState.isStreakActive;
              return GestureDetector(
                onTap: () {
                  ref.read(navigationIndexProvider.notifier).state = 3;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6.0, top: 12.0, bottom: 12.0),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: isSecured ? const Color(0xFF2E6F5E).withValues(alpha: 0.25) : Colors.black26,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isSecured ? const Color(0xFFD4AF37) : Colors.white24,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12.0)),
                      const SizedBox(width: 4.0),
                      Text(
                        streak > 0 ? '$streak' : '0',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: isSecured ? const Color(0xFFD4AF37) : primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
                                _showOutOfSwipes(context, ref);
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
                  if (!ok && feedState.swipesRemaining <= 0 && context.mounted) {
                    _showOutOfSwipes(context, ref);
                  } else if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile passed 🍃'),
                        duration: Duration(milliseconds: 1200),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onResonate: () async {
                  final growthLetters = ref.read(growthHubControllerProvider).directLetters;
                  final prefs = await SharedPreferences.getInstance();
                  final cachedLetters = prefs.getInt('ur_heart_direct_letters') ?? 0;
                  final effectiveLetters = feedState.directLettersCount > 0
                      ? feedState.directLettersCount
                      : (growthLetters > 0 ? growthLetters : cachedLetters);
                  if (effectiveLetters <= 0) {
                    if (context.mounted) {
                      _showOutOfDirectLetters(context, ref);
                    }
                  } else {
                    if (context.mounted) {
                      _openDirectLetterModal(context, current, feedNotifier, isDark, ref);
                    }
                  }
                },
                onLike: () async {
                  final ok = await feedNotifier.swipeLike();
                  if (!ok && feedState.swipesRemaining <= 0 && context.mounted) {
                    _showOutOfSwipes(context, ref);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showOutOfSwipes(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(authControllerProvider).userId;
    showDialog<void>(
      context: context,
      builder: (ctx) => OutOfSwipesAdModal(
        userId: currentUserId.isNotEmpty ? currentUserId : 'current_user',
      ),
    );
  }

  void _showOutOfDirectLetters(BuildContext context, WidgetRef ref) {
    final isDark = ref.read(themeProvider).activeTheme == SanctuaryTheme.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2824) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('💌', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'Direct Letters Needed',
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A2621),
              ),
            ),
          ],
        ),
        content: Text(
          'Direct Sanctuary Letters deliver immediately to a seeker\'s dialogue without waiting for a mutual match. '
          'You can earn free direct letters in the Growth Hub or use a standard Like ♡ for now.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(feedControllerProvider.notifier).swipeLike();
            },
            child: const Text('Send Like ♡ Instead'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C5E43),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(navigationIndexProvider.notifier).state = 3;
            },
            child: const Text('Earn in Growth Hub ➔', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openDirectLetterModal(
    BuildContext context,
    CandidateProfile candidate,
    FeedController feedNotifier,
    bool isDark,
    WidgetRef ref,
  ) {
    final textController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2824) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3D37) : const Color(0xFFE0E5E2),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('💌', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          'Direct Sanctuary Letter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Serif',
                            color: isDark ? Colors.white : const Color(0xFF1A2621),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Write a mindful note directly to ${candidate.fullName}. This bypasses standard waiting and delivers immediately to their dialogue.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  maxLength: 300,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A2621),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share what genuinely resonated with you about their sanctuary...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF141C19) : const Color(0xFFF4F6F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2E3D37) : const Color(0xFFE0E5E2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFD47355),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5E43),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final text = textController.text.trim();
                      Navigator.of(ctx).pop();
                      final ok = await feedNotifier.swipeDirectLetter(letterText: text);
                      if (!ok && context.mounted) {
                        _showOutOfDirectLetters(context, ref);
                      } else if (context.mounted) {
                        final remaining = ref.read(feedControllerProvider).directLettersCount;
                        ref.read(growthHubControllerProvider.notifier).updateDirectLetters(remaining);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Direct letter dispatched to ${candidate.fullName} ✨'),
                            backgroundColor: const Color(0xFF2C5E43),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Dispatch Direct Letter ➔',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
