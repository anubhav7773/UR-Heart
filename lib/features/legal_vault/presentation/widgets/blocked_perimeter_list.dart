import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/vault_models.dart';
import '../controllers/vault_controller.dart';

/// Modal bottom sheet displaying blocked perimeter profiles with unblock actions
class BlockedPerimeterList extends ConsumerWidget {
  final List<BlockedProfile>? blockedList;
  final bool isDark;
  final void Function(String id)? onUnblock;

  const BlockedPerimeterList({
    super.key,
    this.blockedList,
    required this.isDark,
    this.onUnblock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultControllerProvider);
    final currentList = vaultState.blockedList.isNotEmpty 
        ? vaultState.blockedList 
        : (blockedList ?? []);
    final notifier = ref.read(vaultControllerProvider.notifier);

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
                'Blocked Perimeter (${currentList.length})',
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
            'Blocked accounts cannot view your sanctuary moments, dialogue, or discover you.',
            style: AppTypography.bodySmall.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: currentList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 40, color: mutedColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'No accounts in blocked perimeter.',
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: currentList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = currentList[index];
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
                                    '${item.name}${item.age > 0 ? ', ${item.age}' : ''}',
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
                              onPressed: () async {
                                if (onUnblock != null) {
                                  onUnblock!(item.id);
                                } else {
                                  await notifier.unblockUser(item.id);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Unblocked ${item.name}'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: DarkSanctuaryTokens.primaryCoral,
                                    ),
                                  );
                                }
                              },
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

