import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/ad_reward_models.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../controllers/growth_hub_controller.dart';

/// Hero Card for 24-Hour Mindful Streak, Profile Boosting, and Loss Aversion Protection.
class MindfulStreakCard extends ConsumerWidget {
  final bool isDark;
  final String? userId;

  const MindfulStreakCard({super.key, required this.isDark, this.userId});

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0h 0m';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(growthHubControllerProvider);
    final notifier = ref.read(growthHubControllerProvider.notifier);

    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final headline = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final muted = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final coral = const Color(0xFFE06D53);
    final emerald = const Color(0xFF4E9F76);

    final isExpiringSoon = state.isStreakActive && state.secondsRemaining <= 4 * 3600;
    final timerText = _formatSeconds(state.secondsRemaining);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isExpiringSoon
              ? coral
              : (state.isStreakActive ? gold.withValues(alpha: 0.6) : Colors.white12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: state.isStreakActive
                ? gold.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 16.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Fire Icon, Streak Tag & Boost Tier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: coral.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: coral.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '🔥',
                      style: const TextStyle(fontSize: 18.0),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.streakCount > 0
                            ? 'DAY ${state.streakCount} MINDFUL STREAK'
                            : '24-HOUR MINDFUL STREAK',
                        style: TextStyle(
                          fontFamily: 'Serif',
                          color: gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        state.isStreakActive
                            ? 'Secured • $timerText left'
                            : 'Inactive • Resurrect today',
                        style: TextStyle(
                          color: isExpiringSoon ? coral : (state.isStreakActive ? emerald : muted),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Boost Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: gold, size: 14.0),
                    const SizedBox(width: 4.0),
                    Text(
                      '+${state.boostPoints * 25}% Boost',
                      style: TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Body Description
          Text(
            'Keep your daily streak to remain at the top of prospective matches\' discovery deck. Higher streak = maximum incoming likes.',
            style: TextStyle(color: headline, fontSize: 13.0, height: 1.45),
          ),
          const SizedBox(height: 10.0),

          // Loss Aversion Warning Box
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: coral, size: 18.0),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Missing 24h forfeits 1 Social Reveal Token and resets profile discovery boost.',
                    style: TextStyle(
                      color: coral.withValues(alpha: 0.9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                notifier.triggerRewardedAd(
                  adType: AdPlacementTypes.dailyStreakBoost,
                  userId: userId,
                  targetId: 'none',
                  context: context,
                );
              },
              icon: Icon(
                state.isStreakActive ? Icons.lock_clock : Icons.play_arrow_rounded,
                size: 18.0,
                color: Colors.white,
              ),
              label: Text(
                state.isStreakActive
                    ? 'Reinforce Streak & Boost (30s)'
                    : 'Watch 30s Sponsor (+1 Boost & Lock Streak)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.isStreakActive ? const Color(0xFF2E6F5E) : coral,
                padding: const EdgeInsets.symmetric(vertical: 13.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
