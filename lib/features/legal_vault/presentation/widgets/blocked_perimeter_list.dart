import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/vault_models.dart';

/// Modal bottom sheet displaying blocked perimeter profiles with unblock actions
class BlockedPerimeterList extends StatelessWidget {
  final List<BlockedProfile> blockedList;
  final bool isDark;
  final void Function(String id) onUnblock;

  const BlockedPerimeterList({
    super.key,
    required this.blockedList,
    required this.isDark,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final tileBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.chipBackground;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Blocked Perimeter (${blockedList.length})',
                style: AppTypography.titleH2.copyWith(fontSize: 18, color: headlineColor),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: mutedColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Blocked accounts cannot view your sanctuary moments or discover you.',
            style: AppTypography.bodySmall.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: blockedList.isEmpty
                ? Center(
                    child: Text(
                      'No accounts in blocked perimeter.',
                      style: TextStyle(color: mutedColor),
                    ),
                  )
                : ListView.separated(
                    itemCount: blockedList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = blockedList[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: mutedColor.withValues(alpha: 0.2),
                              child: Text(
                                item.name.isNotEmpty ? item.name[0] : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: headlineColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.name}, ${item.age}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: headlineColor,
                                    ),
                                  ),
                                  Text(
                                    'Blocked on ${item.dateBlocked}',
                                    style: TextStyle(fontSize: 11, color: mutedColor),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => onUnblock(item.id),
                              child: const Text(
                                'Unblock',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
