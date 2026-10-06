import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../../../core/theme/sanctuary_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/blind_date_controller.dart';
import 'blind_date_session_screen.dart';

class BlindDateHubScreen extends ConsumerStatefulWidget {
  static const String routeName = '/blind-date';

  const BlindDateHubScreen({super.key});

  @override
  ConsumerState<BlindDateHubScreen> createState() => _BlindDateHubScreenState();
}

class _BlindDateHubScreenState extends ConsumerState<BlindDateHubScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isModalShowing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blindDateControllerProvider.notifier).fetchEligibility();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blindDateControllerProvider);
    final controller = ref.read(blindDateControllerProvider.notifier);
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState.authenticatedUserId ?? '';

    // Auto-navigate when matched
    ref.listen<BlindDateState>(blindDateControllerProvider, (prev, next) {
      if (next.queueStatus == BlindDateQueueStatus.matched &&
          next.session != null) {
        Navigator.of(context).pushReplacementNamed(
          BlindDateSessionScreen.routeName,
        );
      }
      if (next.needsPassUnlock && !_isModalShowing) {
        _isModalShowing = true;
        _showEqualPerksDialog(context, currentUserId).whenComplete(() {
          _isModalShowing = false;
        });
      }
    });

    final isWaiting = state.queueStatus == BlindDateQueueStatus.waiting;

    return Scaffold(
      backgroundColor: SanctuaryColors.midnightObsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: SanctuaryColors.crispIvory),
          onPressed: () {
            if (isWaiting) {
              controller.cancelQueue();
            }
            Navigator.of(context).maybePop();
          },
        ),
        title: const Text(
          'Sanctuary Blind Date',
          style: TextStyle(
            color: SanctuaryColors.crispIvory,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Sunday Pulse & 24/7 Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: SanctuaryColors.glowingTerracotta.withAlpha(35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: SanctuaryColors.glowingTerracotta.withAlpha(90),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: SanctuaryColors.glowingTerracotta,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pulse: Sunday 8 PM IST • Active 24/7',
                      style: TextStyle(
                        color: SanctuaryColors.glowingTerracotta,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Equal Perks: Streak & Pass Status Card
              _buildPerksStatusCard(context, state, controller, currentUserId),

              const SizedBox(height: 28),

              // Animated Pulsing Radar / Mysterious Centerpiece
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = isWaiting ? (1.0 + _pulseAnimation.value * 0.15) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              SanctuaryColors.glowingTerracotta.withAlpha(isWaiting ? 80 : 35),
                              SanctuaryColors.elevatedSlate.withAlpha(120),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: isWaiting
                                ? SanctuaryColors.glowingTerracotta.withAlpha(180)
                                : SanctuaryColors.mutedCharcoalBorder,
                            width: 2,
                          ),
                          boxShadow: isWaiting
                              ? [
                                  BoxShadow(
                                    color: SanctuaryColors.glowingTerracotta.withAlpha(80),
                                    blurRadius: 30,
                                    spreadRadius: 6,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Icon(
                            isWaiting ? Icons.radar : Icons.masks_outlined,
                            size: 64,
                            color: isWaiting
                                ? SanctuaryColors.glowingTerracotta
                                : SanctuaryColors.crispIvory.withAlpha(200),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              Text(
                isWaiting ? 'Seeking Resonant Soul...' : 'Awaaz & Soul Connection First',
                style: const TextStyle(
                  color: SanctuaryColors.crispIvory,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                isWaiting
                    ? 'Scanning across all identities with 100% mutual alignment. Please hold this sacred space.'
                    : 'Experience dating stripped of superficial snap judgments. 5 minutes of veiled dialogue, real voices, and soulful resonance.',
                style: TextStyle(
                  color: SanctuaryColors.softGreySubtext.withAlpha(220),
                  fontSize: 14,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: SanctuaryColors.alertRed.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SanctuaryColors.alertRed.withAlpha(90)),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: SanctuaryColors.alertRed, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Feature Pillars
              _buildFeaturePill(
                icon: Icons.diversity_1_rounded,
                title: '3-Gender Equal Harmony',
                subtitle: 'Fair & accurate for Men, Women & Non-Binary seekers.',
              ),
              const SizedBox(height: 12),
              _buildFeaturePill(
                icon: Icons.shield_rounded,
                title: 'DPDP Act 2023 Shielded',
                subtitle: 'Photos heavily veiled (35px). Zero screenshots or raw URL leaks.',
              ),
              const SizedBox(height: 12),
              _buildFeaturePill(
                icon: Icons.graphic_eq_rounded,
                title: 'Voice Sparks Included',
                subtitle: 'Hear genuine 7-second voice notes before seeing faces.',
              ),
              const SizedBox(height: 12),
              _buildFeaturePill(
                icon: Icons.lock_clock_rounded,
                title: 'Mutual Consent Gate',
                subtitle: 'Photos unblur only if both parties tap "Resonate" at the end.',
              ),

              const SizedBox(height: 36),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          if (isWaiting) {
                            controller.cancelQueue();
                          } else {
                            controller.joinQueue();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWaiting
                        ? SanctuaryColors.elevatedSlate
                        : SanctuaryColors.glowingTerracotta,
                    foregroundColor: SanctuaryColors.crispIvory,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isWaiting
                          ? const BorderSide(color: SanctuaryColors.mutedCharcoalBorder)
                          : BorderSide.none,
                    ),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: SanctuaryColors.crispIvory,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isWaiting ? Icons.close : Icons.favorite_border_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isWaiting ? 'Leave Queue' : 'Enter The Mystery',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SanctuaryColors.elevatedSlate,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SanctuaryColors.mutedCharcoalBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SanctuaryColors.midnightObsidian,
              shape: BoxShape.circle,
              border: Border.all(
                color: SanctuaryColors.glowingTerracotta.withAlpha(60),
              ),
            ),
            child: Icon(icon, color: SanctuaryColors.glowingTerracotta, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SanctuaryColors.crispIvory,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: SanctuaryColors.softGreySubtext.withAlpha(200),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerksStatusCard(
    BuildContext context,
    BlindDateState state,
    BlindDateController controller,
    String userId,
  ) {
    final eligibility = state.eligibility;
    final isStreakActive = eligibility?.isStreakActive ?? false;
    final streakCount = eligibility?.streakCount ?? 0;
    final hasDailyPass = eligibility?.hasDailyStreakPass ?? false;
    final bonusPasses = eligibility?.bonusPasses ?? 0;
    final totalPasses = (hasDailyPass ? 1 : 0) + bonusPasses;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SanctuaryColors.elevatedSlate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStreakActive
              ? SanctuaryColors.resonantGold.withAlpha(80)
              : SanctuaryColors.mutedCharcoalBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isStreakActive
                      ? SanctuaryColors.resonantGold.withAlpha(30)
                      : SanctuaryColors.softGreySubtext.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isStreakActive
                        ? SanctuaryColors.resonantGold.withAlpha(120)
                        : SanctuaryColors.mutedCharcoalBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: isStreakActive
                          ? SanctuaryColors.resonantGold
                          : SanctuaryColors.softGreySubtext,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isStreakActive ? '$streakCount Day Streak' : 'Streak Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isStreakActive
                            ? SanctuaryColors.resonantGold
                            : SanctuaryColors.softGreySubtext,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: totalPasses > 0
                      ? SanctuaryColors.onlineEmerald.withAlpha(30)
                      : SanctuaryColors.alertRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: totalPasses > 0
                        ? SanctuaryColors.onlineEmerald.withAlpha(120)
                        : SanctuaryColors.alertRed.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 15,
                      color: totalPasses > 0
                          ? SanctuaryColors.onlineEmerald
                          : SanctuaryColors.alertRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalPasses Passes Ready',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: totalPasses > 0
                            ? SanctuaryColors.onlineEmerald
                            : SanctuaryColors.alertRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isStreakActive
                ? (hasDailyPass
                    ? '✨ Today\'s Free Streak Pass is Active!'
                    : '⚡ Today\'s free pass used. Stored bonus passes: $bonusPasses')
                : '🔒 Daily 1 Free Pass is locked. Maintain streak or watch 1 ad to ignite!',
            style: TextStyle(
              color: SanctuaryColors.crispIvory.withAlpha(230),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(
            color: SanctuaryColors.mutedCharcoalBorder,
            height: 1,
            thickness: 0.8,
          ),
          const SizedBox(height: 8),
          // Fast-Track Radar Toggle
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 20,
                color: SanctuaryColors.resonantGold,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fast-Track Radar (Equal VIP)',
                      style: TextStyle(
                        color: SanctuaryColors.crispIvory,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Jump to top of matchmaking queue (Free for All)',
                      style: TextStyle(
                        color: SanctuaryColors.softGreySubtext,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.isFastTrack,
                onChanged: (val) => controller.toggleFastTrack(val),
                activeColor: SanctuaryColors.glowingTerracotta,
              ),
            ],
          ),
          if (totalPasses == 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _showEqualPerksDialog(context, userId),
                icon: const Icon(Icons.stars_rounded, size: 16, color: SanctuaryColors.resonantGold),
                label: const Text(
                  'Unlock Passes / Ignite Streak',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SanctuaryColors.crispIvory,
                  side: const BorderSide(color: SanctuaryColors.glowingTerracotta),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEqualPerksDialog(BuildContext context, String userId) async {
    final controller = ref.read(blindDateControllerProvider.notifier);
    final state = ref.read(blindDateControllerProvider);
    final eligibility = state.eligibility;
    final isStreakActive = eligibility?.isStreakActive ?? false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SanctuaryColors.elevatedSlate,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SanctuaryColors.mutedCharcoalBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SanctuaryColors.glowingTerracotta.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: SanctuaryColors.glowingTerracotta,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equal Perks System',
                          style: TextStyle(
                            color: SanctuaryColors.crispIvory,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Zero Class Discrimination • 1:1 Value Parity',
                          style: TextStyle(
                            color: SanctuaryColors.softGreySubtext,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SanctuaryColors.midnightObsidian,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SanctuaryColors.mutedCharcoalBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isStreakActive
                              ? Icons.local_fire_department
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: isStreakActive
                              ? SanctuaryColors.resonantGold
                              : SanctuaryColors.glowingTerracotta,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isStreakActive
                              ? 'Daily 1 Free Pass Claimed'
                              : 'Daily 1 Free Pass Locked (Streak Inactive)',
                          style: const TextStyle(
                            color: SanctuaryColors.crispIvory,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isStreakActive
                          ? 'You have used today\'s free streak pass. Unlock another pass below!'
                          : 'Daily 1 free pass is granted to seekers maintaining their streak. Watching an ad will restore your streak AND grant a pass!',
                      style: TextStyle(
                        color: SanctuaryColors.softGreySubtext.withAlpha(200),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Option A: Watch 30s Ad (100% Free)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  controller.setNeedsPassUnlock(false);
                  RewardedAdManager.instance.showRewardedAd(
                    userId: userId,
                    adType: 'blind_date_pass',
                    targetId: 'none',
                    context: context,
                    onRewardGranted: () async {
                      final success = await controller.claimAdPass();
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✨ Streak Active & +1 Blind Date Pass Unlocked!'),
                            backgroundColor: SanctuaryColors.onlineEmerald,
                          ),
                        );
                      }
                    },
                    onPlaybackFailed: (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reflection paused: $err')),
                        );
                      }
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SanctuaryColors.glowingTerracotta,
                  foregroundColor: SanctuaryColors.crispIvory,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isStreakActive
                          ? 'Watch 30s Reflection for +1 Pass (Free)'
                          : 'Watch 30s Ad: Ignite Streak & Unlock Pass',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Option B: ₹29 Direct Pass (Equal Value)
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  controller.setNeedsPassUnlock(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ Instant ₹29 Pass credited to your Sanctuary account!'),
                    ),
                  );
                  // Grant pass directly for instant IAP simulation/integration
                  controller.claimAdPass();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: SanctuaryColors.crispIvory,
                  side: const BorderSide(color: SanctuaryColors.mutedCharcoalBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 20, color: SanctuaryColors.resonantGold),
                    SizedBox(width: 8),
                    Text(
                      'Unlock Instant Pass (₹29)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

