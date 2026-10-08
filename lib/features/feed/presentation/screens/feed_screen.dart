import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
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
            // Sanctuary Blind Date Entry Banner (Teaser & 1M Milestone Awakening)
            GestureDetector(
              onTap: () => _showBlindPulseMilestoneModal(context, isDark, ref),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B20) : const Color(0xFFF0EAE1),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: const Color(0xFFD97746).withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97746).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.masks_outlined,
                        color: Color(0xFFD97746),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Sanctuary Blind Date',
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97746).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD97746).withValues(alpha: 0.4), width: 0.8),
                                ),
                                child: const Text(
                                  '1M MILESTONE 🔒',
                                  style: TextStyle(
                                    color: Color(0xFFD97746),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Cosmic veiled soul resonance • Coming at 1M Pan-India Seekers',
                            style: TextStyle(
                              color: subText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Color(0xFFD97746),
                    ),
                  ],
                ),
              ),
            ),
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

  void _showBlindPulseMilestoneModal(BuildContext context, bool isDark, WidgetRef ref) {
    final surface = isDark ? const Color(0xFF181B20) : Colors.white;
    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    const terracotta = Color(0xFFD97746);
    const gold = Color(0xFFD4AF37);

    final growthState = ref.read(growthHubControllerProvider);
    final refCode = growthState.referralCode.isNotEmpty ? growthState.referralCode : 'UR-SANCTUARY';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: terracotta.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pill drag handle
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sovereign Milestone Lock Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: terracotta.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: terracotta.withValues(alpha: 0.4), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 14, color: terracotta),
                    SizedBox(width: 6),
                    Text(
                      'SOVEREIGN MILESTONE LOCK',
                      style: TextStyle(
                        color: terracotta,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'Blind Pulse: Cosmic Veiled Encounters',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              // Core 1M Pan-India Requirement (English as requested)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: terracotta.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: terracotta.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.stars_rounded, color: gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This sovereign feature is coming soon and will unlock exclusively once UR-Heart achieves 1,000,000 Daily Active Seekers Pan-India.',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Curiosity & Viral Marketing Narrative
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✨ The Sacred Experience Awaiting You:',
                      style: TextStyle(
                        color: gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• 5-Minute Veiled Soul Dialogue: Profiles, photos, and superficial attributes remain strictly veiled.\n'
                      '• Pure Chemistry: Match solely through real-time emotional wavelength and unmasked conversation.\n'
                      '• Mutual Consent Reveal: Faces only illuminate if both seekers mutually choose to unveil at the finale.\n'
                      '• High-Density Cosmic Radius: The portal requires a deep sanctuary mesh across every Indian city to guarantee instantaneous, authentic pairings without idle waiting.',
                      style: TextStyle(
                        color: subText,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Viral Call to Action Button: Share Sanctuary Crest
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final shareText =
                        'Join me in UR-Heart — A mindful sanctuary of soul-first connection without superficial swiping.\n'
                        'Fast-track the 1M Blind Pulse Awakening with my Passage Crest: $refCode\n'
                        'https://urheart.asiverticals.me/join?ref=$refCode';
                    try {
                      await Share.share(
                        shareText,
                        subject: 'Accelerate the 1M Blind Pulse Awakening on UR-Heart',
                      );
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF0B1410)),
                  label: const Text(
                    'Invite Kindred Spirits (Fast-Track 1M) 🕊️',
                    style: TextStyle(
                      color: Color(0xFF0B1410),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Dismiss
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'I Will Await the Pulse',
                  style: TextStyle(
                    color: subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
