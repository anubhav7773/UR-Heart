import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/vault_repository.dart';

/// Centralized Controllers for Statutory Vault & Legal Compliance CTAs (ACT-05, ACT-13, ACT-20 Fix)
class VaultActionControllers {
  /// ACT-05 FIX: Real Unblock Action against Database
  static Future<void> handleUnblockUser({
    required BuildContext context,
    required WidgetRef ref,
    required String blockedUserId,
    required VoidCallback onRefreshList,
  }) async {
    try {
      final success = await ref.read(vaultRepositoryProvider).unblockUser(blockedUserId);
      if (success) {
        onRefreshList();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User removed from blocked perimeter.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove user from perimeter.')),
        );
      }
    }
  }

  /// ACT-13 FIX: Poll & Download Genuine DPDP Data Archive
  static Future<void> handleDownloadArchive({
    required BuildContext context,
    required WidgetRef ref,
    required String requestId,
  }) async {
    try {
      final status = await ref.read(vaultRepositoryProvider).checkExportStatus(requestId);
      if (status.isReady && status.downloadUrl != null) {
        final uri = Uri.parse(status.downloadUrl ?? '');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export bundle is still compiling. Please tap again in a moment.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to download archive.')),
        );
      }
    }
  }

  /// ACT-20 FIX: Persist Legal Nominee with Valid Schema
  static Future<void> handleNomineeConfirmation({
    required BuildContext context,
    required WidgetRef ref,
    required String name,
    required String contact,
    required String relationship,
  }) async {
    try {
      final nominee = await ref.read(vaultRepositoryProvider).designateNominee(
        name: name,
        contact: contact,
        relationship: relationship,
      );
      if (nominee.isDesignated && context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statutory Nominee registered under DPDP Act Sec 14.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nominee registration failed: ${e.toString()}')),
        );
      }
    }
  }
}
