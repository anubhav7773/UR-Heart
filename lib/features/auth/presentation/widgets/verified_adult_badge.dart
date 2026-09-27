import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';

/// Real-time live age calculation badge and underage protection pill
class VerifiedAdultBadge extends ConsumerWidget {
  const VerifiedAdultBadge({super.key});

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final verifiedBadgeColor = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    if (!authState.hasSelectedFullDob) {
      return const SizedBox.shrink();
    }

    final day = authState.selectedDay ?? 1;
    final monthIndex = (authState.selectedMonth ?? 1) - 1;
    final monthStr = _months[monthIndex];
    final year = authState.selectedYear ?? 2000;
    final age = authState.calculatedAge ?? 0;

    if (authState.isUnderageBlocked || age < 18) {
      return Container(
        margin: const EdgeInsets.only(top: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE63946).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: const Color(0xFFE63946), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE63946), size: 16.0),
            const SizedBox(width: 8.0),
            Flexible(
              child: Text(
                '$day $monthStr $year · $age yrs old · Underage (18+ Mandatory)',
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFFE63946),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: verifiedBadgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: verifiedBadgeColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: verifiedBadgeColor, size: 16.0),
          const SizedBox(width: 8.0),
          Text(
            '$day $monthStr $year · $age yrs old · Verified Adult',
            style: AppTypography.caption.copyWith(
              color: verifiedBadgeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
