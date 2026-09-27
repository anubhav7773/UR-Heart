import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/feed_controller.dart';
import 'out_of_swipes_modal.dart';

/// Modal triggered when user exhausts daily swipes quota
class OutOfSwipesAdModal extends ConsumerWidget {
  const OutOfSwipesAdModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;
    final feedNotifier = ref.read(feedControllerProvider.notifier);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: OutOfSwipesModal(
          isDark: isDark,
          onWatchAdTriggered: () {
            feedNotifier.replenishSwipes(10);
          },
        ),
      ),
    );
  }
}
