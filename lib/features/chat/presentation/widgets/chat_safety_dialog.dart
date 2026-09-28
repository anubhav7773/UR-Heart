import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../legal_vault/data/vault_repository.dart';
import '../../../ai_sanctuary/presentation/widgets/ai_grievance_assistant_sheet.dart';

/// Modal for Reporting or Blocking a user in Direct DM
class ChatSafetyDialog {
  /// Confirms and executes user block
  static Future<void> showBlockConfirmation({
    required BuildContext context,
    required WidgetRef ref,
    required String recipientId,
    required String recipientName,
    required bool isDark,
    required VoidCallback onUserBlocked,
  }) async {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final alertColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.block_rounded, color: alertColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Block $recipientName?',
                style: AppTypography.titleH2.copyWith(
                  color: headlineColor,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$recipientName will no longer be able to send you direct messages, view your sanctuary persona, or appear in your deck. This conversation will be closed immediately.',
          style: TextStyle(color: mutedColor, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: mutedColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: alertColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block User', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(vaultRepositoryProvider).blockUser(
          recipientId,
          reason: 'Direct DM user report/block',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$recipientName has been blocked from your Sanctuary.'),
              backgroundColor: alertColor,
              duration: const Duration(seconds: 3),
            ),
          );
          onUserBlocked();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error blocking user: $e')),
          );
        }
      }
    }
  }

  /// Opens statutory grievance reporting sheet with category & evidence fields
  static Future<void> showReportSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String recipientId,
    required String recipientName,
    required bool isDark,
    required VoidCallback onUserBlocked,
  }) async {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final pineColor = isDark
        ? DarkSanctuaryTokens.secondaryPine
        : LightSanctuaryTokens.primaryPine;

    final categories = [
      'Harassment or Repeated Unwanted Contact',
      'Inappropriate or Explicit Content',
      'Hate Speech or Intimidation',
      'Impersonation or False Identity',
      'Spam, Commercial, or Scams',
      'Underage Account Suspicion',
    ];

    String selectedCategory = categories.first;
    final evidenceController = TextEditingController();
    bool alsoBlock = true;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.report_problem_rounded, color: accentColor, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Report $recipientName',
                        style: AppTypography.titleH2.copyWith(
                          color: headlineColor,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Statutory filing under IT Rules 2021 Rule 3(2). All reports are reviewed by our Grievance Officer within 24 hours.',
                    style: TextStyle(color: mutedColor, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      AiGrievanceAssistantSheet.show(
                        context: context,
                        offenderName: recipientName,
                        isDark: isDark,
                        onCategorySuggested: (cat) {
                          setState(() => selectedCategory = cat);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confused? Ask Eva to help write & categorize your report',
                              style: TextStyle(
                                color: headlineColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 16, color: accentColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reason for Report',
                    style: TextStyle(color: headlineColor, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: bgColor,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: mutedColor.withValues(alpha: 0.3)),
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat, style: TextStyle(color: headlineColor, fontSize: 12.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Additional Context or Evidence (Optional)',
                    style: TextStyle(color: headlineColor, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: evidenceController,
                    maxLines: 3,
                    style: TextStyle(color: headlineColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Describe what occurred or paste message context...',
                      hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.6), fontSize: 12.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: mutedColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: alsoBlock,
                    contentPadding: EdgeInsets.zero,
                    activeColor: accentColor,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Also block $recipientName immediately',
                      style: TextStyle(color: headlineColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Terminates direct DM thread and restricts interactions',
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                    onChanged: (val) {
                      setState(() => alsoBlock = val ?? false);
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setState(() => isSubmitting = true);
                              try {
                                final receipt = await ref.read(vaultRepositoryProvider).fileGrievanceDossier(
                                  reportedUserId: recipientId,
                                  violationCategory: selectedCategory,
                                  evidenceText: evidenceController.text.trim(),
                                );

                                if (alsoBlock) {
                                  await ref.read(vaultRepositoryProvider).blockUser(
                                    recipientId,
                                    reason: selectedCategory,
                                  );
                                }

                                if (context.mounted) {
                                  Navigator.of(sheetContext).pop();
                                  showDialog<void>(
                                    context: context,
                                    builder: (ackCtx) => AlertDialog(
                                      backgroundColor: bgColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Row(
                                        children: [
                                          Icon(Icons.verified_user_rounded, color: pineColor, size: 24),
                                          const SizedBox(width: 8),
                                          Text('Report Acknowledged', style: TextStyle(color: headlineColor, fontSize: 16)),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Grievance Dossier #${receipt.dossierReferenceId}',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: pineColor, fontSize: 14),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Your report has been logged and assigned for statutory investigation. We adhere strictly to zero-tolerance policies.',
                                            style: TextStyle(color: mutedColor, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: pineColor),
                                          onPressed: () {
                                            Navigator.of(ackCtx).pop();
                                            if (alsoBlock) onUserBlocked();
                                          },
                                          child: const Text('Understood', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to submit report: $e')),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Submit Statutory Report',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
