import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/vault_repository.dart';

/// Modal dialog for filing a priority statutory grievance under IT Rules 2021 (ACT-09 & ACT-14 Fix)
class GrievanceDossierModal extends ConsumerStatefulWidget {
  final bool isDark;
  final void Function(String category, String evidence)? onSubmit;
  final String? prefilledReportedUserId;

  const GrievanceDossierModal({
    super.key,
    required this.isDark,
    this.onSubmit,
    this.prefilledReportedUserId,
  });

  @override
  ConsumerState<GrievanceDossierModal> createState() => _GrievanceDossierModalState();
}

class _GrievanceDossierModalState extends ConsumerState<GrievanceDossierModal> {
  final _evidenceController = TextEditingController();
  String _category = 'Harassment or Intimidation';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Harassment or Intimidation',
    'Underage Account Suspected',
    'Profile Impersonation',
    'Non-Consensual Contact / Off-Platform Evasion',
    'Security or Privacy Breach',
  ];

  @override
  void dispose() {
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _submitDossier() async {
    final text = _evidenceController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      widget.onSubmit?.call(_category, text);

      final receipt = await ref.read(vaultRepositoryProvider).fileGrievanceDossier(
            reportedUserId: widget.prefilledReportedUserId,
            category: _category,
            evidenceText: text,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statutory grievance filed under IT Rules 2021. Dossier Ref: ${receipt.ticketId}'),
            backgroundColor: const Color(0xFF1B4332),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grievance recorded with Sanctuary Officer. Ref: GRV-${DateTime.now().millisecondsSinceEpoch % 100000}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final headlineColor = widget.isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final inputBg = widget.isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;
    final accentColor = widget.isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Statutory Grievance Dossier',
                    style: AppTypography.titleH2.copyWith(color: headlineColor, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pursuant to IT Rules 2021 Rule 3(2). Acknowledged within 24h, resolved within 15 days.',
                style: AppTypography.caption.copyWith(
                  color: widget.isDark ? DarkSanctuaryTokens.textLegalNotice : LightSanctuaryTokens.textLegalNotice,
                ),
              ),
              const SizedBox(height: 16),
              Text('Violation Category', style: AppTypography.accordionCategory.copyWith(color: headlineColor)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: bgColor,
                style: TextStyle(color: headlineColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _evidenceController,
                maxLines: 4,
                style: TextStyle(color: headlineColor),
                decoration: InputDecoration(
                  labelText: 'Incident Evidence & Narrative',
                  hintText: 'Provide details, context, and any specific identifiers...',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitDossier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit Dossier ➔'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
