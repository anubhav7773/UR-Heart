import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import 'feed_action_handlers.dart';
import 'out_of_swipes_modal.dart';

/// Modal triggered when user exhausts daily swipes quota (ACT-02 Fix)
class OutOfSwipesAdModal extends ConsumerWidget {
  final String userId;

  const OutOfSwipesAdModal({super.key, this.userId = 'current_user'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: OutOfSwipesModal(
          isDark: isDark,
          onWatchAdTriggered: () {
            Navigator.of(context).pop();
            FeedActionHandlers.handleOutOfSwipesReward(
              context: context,
              ref: ref,
              userId: userId,
              isDark: isDark,
            );
          },
        ),
      ),
    );
  }
}
