import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/sanctuary_colors.dart';
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

    // Auto-navigate when matched
    ref.listen<BlindDateState>(blindDateControllerProvider, (prev, next) {
      if (next.queueStatus == BlindDateQueueStatus.matched &&
          next.session != null) {
        Navigator.of(context).pushReplacementNamed(
          BlindDateSessionScreen.routeName,
        );
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
              const SizedBox(height: 12),
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
}
