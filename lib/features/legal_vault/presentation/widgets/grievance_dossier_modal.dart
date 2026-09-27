import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Modal dialog for filing a priority statutory grievance under IT Rules 2021
class GrievanceDossierModal extends StatefulWidget {
  final bool isDark;
  final void Function(String category, String evidence) onSubmit;

  const GrievanceDossierModal({
    super.key,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<GrievanceDossierModal> createState() => _GrievanceDossierModalState();
}

class _GrievanceDossierModalState extends State<GrievanceDossierModal> {
  final _evidenceController = TextEditingController();
  String _category = 'Harassment or Intimidation';

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
              Text(
                'File Statutory Grievance Dossier',
                style: AppTypography.titleH2.copyWith(fontSize: 18, color: headlineColor),
              ),
              const SizedBox(height: 6),
              Text(
                'IT Rules 2021 Rule 3(2) statutory desk. Official SLA: Acknowledged within 24 hours, resolved within 15 days.',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark
                      ? DarkSanctuaryTokens.textMuted
                      : LightSanctuaryTokens.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: bgColor,
                style: TextStyle(color: headlineColor),
                decoration: InputDecoration(
                  labelText: 'Grievance Classification',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _category = val);
                  }
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
                    onPressed: () {
                      final text = _evidenceController.text.trim();
                      if (text.isNotEmpty) {
                        widget.onSubmit(_category, text);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Submit Dossier ➔'),
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
