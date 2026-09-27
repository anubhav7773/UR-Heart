import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Modal dialog for appointing a Data Nominee under DPDP Act 2023 Sec 14
class NomineeDesignationModal extends StatefulWidget {
  final bool isDark;
  final void Function(String name, String contact, String relationship) onSubmit;

  const NomineeDesignationModal({
    super.key,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<NomineeDesignationModal> createState() => _NomineeDesignationModalState();
}

class _NomineeDesignationModalState extends State<NomineeDesignationModal> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  String _relationship = 'Sibling';

  final List<String> _relationships = [
    'Sibling',
    'Partner',
    'Parent',
    'Trusted Friend',
    'Legal Executor',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
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
                'Designate Data Nominee',
                style: AppTypography.titleH2.copyWith(fontSize: 18, color: headlineColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Pursuant to DPDP Act 2023 Section 14, nominate an individual to exercise data rights in the event of death or incapacity.',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark
                      ? DarkSanctuaryTokens.textMuted
                      : LightSanctuaryTokens.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: TextStyle(color: headlineColor),
                decoration: InputDecoration(
                  labelText: 'Nominee Full Legal Name',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                style: TextStyle(color: headlineColor),
                decoration: InputDecoration(
                  labelText: 'Contact (Email or Mobile)',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _relationship,
                dropdownColor: bgColor,
                style: TextStyle(color: headlineColor),
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _relationship = val);
                  }
                },
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
                      final name = _nameController.text.trim();
                      final contact = _contactController.text.trim();
                      if (name.isNotEmpty && contact.isNotEmpty) {
                        widget.onSubmit(name, contact, _relationship);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirm Nominee ➔'),
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
