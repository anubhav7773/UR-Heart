import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import 'irrevocable_erasure_modal.dart';

/// Sovereign Control section containing Log Out and DPDP Sec 12 Account Incinerator (< 120 lines)
class SovereignControlSection extends StatelessWidget {
  final bool isDark;
  final bool isIncinerating;
  final VoidCallback onLogOut;
  final VoidCallback onConfirmErasure;

  const SovereignControlSection({
    super.key,
    required this.isDark,
    required this.isIncinerating,
    required this.onLogOut,
    required this.onConfirmErasure,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final crimsonColor = isDark ? DarkSanctuaryTokens.crimsonDelete : LightSanctuaryTokens.crimsonDelete;
    final crimsonBorder = isDark ? DarkSanctuaryTokens.crimsonDeleteBorder : LightSanctuaryTokens.crimsonDeleteBorder;
    final crimsonBg = isDark ? DarkSanctuaryTokens.crimsonDeleteBackground : LightSanctuaryTokens.crimsonDeleteBackground;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sovereign Control & Account Lifecycle',
            style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
          ),
          const SizedBox(height: 12),
          // 1. Log Out Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.chipBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Out of Sanctuary',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: headlineColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clears ephemeral in-memory session tokens and encryption keys.',
                        style: AppTypography.bodySmall.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onLogOut,
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 2. DPDP Act Sec 12 Cryptographic Account Shredder
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crimsonBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crimsonBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: crimsonColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Delete Account & Erase All Data',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crimsonColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Statutory DPDP Act Sec 12 cryptographic incinerator. All letters, photos, and encryption keys are permanently destroyed across all servers.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? const Color(0xFFFFB4AB) : const Color(0xFF93000A),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: isIncinerating
                        ? null
                        : () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => IrrevocableErasureModal(
                                isDark: isDark,
                                onConfirmErasure: onConfirmErasure,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: crimsonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isIncinerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Erase Everything Irrevocably ➔',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
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
