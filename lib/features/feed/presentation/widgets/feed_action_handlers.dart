import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../data/feed_repository.dart';
import '../controllers/feed_controller.dart';
import '../../../legal_vault/presentation/widgets/grievance_dossier_modal.dart';

/// Centralized Action Handlers for Sanctuary Feed Deck (ACT-02, ACT-09, ACT-10, ACT-23 Fix)
class FeedActionHandlers {
  /// ACT-02 FIX: Verified Rewarded Ad Playback & Server Balance Replenish
  static void handleOutOfSwipesReward({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required bool isDark,
  }) {
    RewardedAdManager.instance.showRewardedAd(
      userId: userId,
      adType: 'quick_reflection',
      targetId: 'none',
      onRewardGranted: () async {
        // Refresh live feed state to read server-credited swipes
        await ref.read(feedControllerProvider.notifier).loadFeed();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('+10 Reflection Swipes Verified and Added.')),
          );
        }
      },
      onPlaybackFailed: (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sponsor reflection paused: $error')),
          );
        }
      },
    );
  }

  /// ACT-09 FIX: Report Candidate Profile & File Statutory Grievance
  static void openReportModal({
    required BuildContext context,
    required String reportedUserId,
    required bool isDark,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GrievanceDossierModal(
        isDark: isDark,
        prefilledReportedUserId: reportedUserId,
      ),
    );
  }

  /// ACT-10 FIX: Rewind / Restore Passed Candidate Card
  static Future<void> handlePassRewind({
    required BuildContext context,
    required WidgetRef ref,
    required String targetUserId,
  }) async {
    try {
      final success = await ref.read(feedRepositoryProvider).restorePassedProfile(targetUserId);
      if (success) {
        await ref.read(feedControllerProvider.notifier).loadFeed();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Candidate restored to your deck.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to restore profile at this moment.')),
        );
      }
    }
  }

  /// ACT-23 FIX: Deck Refresh Action
  static Future<void> handleRefreshDeck({required WidgetRef ref}) async {
    await ref.read(feedControllerProvider.notifier).loadFeed();
  }
}
