import 'package:flutter/material.dart';

class GenderOption {
  final String key;
  final String label;
  final String category;
  final String description;

  const GenderOption({
    required this.key,
    required this.label,
    required this.category,
    required this.description,
  });
}

const List<GenderOption> kGenderSpectrum = [
  GenderOption(key: 'male', label: 'Man (पुरुष)', category: 'Binary', description: 'Identifies as male/man'),
  GenderOption(key: 'female', label: 'Woman (महिला)', category: 'Binary', description: 'Identifies as female/woman'),
  GenderOption(key: 'non_binary', label: 'Non-Binary', category: 'LGBTQ+', description: 'Identity outside the male/female binary'),
  GenderOption(key: 'trans_woman', label: 'Transgender Woman (Trans Female)', category: 'LGBTQ+', description: 'Assigned male at birth, identifies as woman'),
  GenderOption(key: 'trans_man', label: 'Transgender Man (Trans Male)', category: 'LGBTQ+', description: 'Assigned female at birth, identifies as man'),
  GenderOption(key: 'genderfluid', label: 'Genderfluid', category: 'LGBTQ+', description: 'Gender identity shifts or fluctuates over time'),
  GenderOption(key: 'agender', label: 'Agender', category: 'LGBTQ+', description: 'Identifies as having no gender or genderless'),
  GenderOption(key: 'queer', label: 'Genderqueer / Queer', category: 'LGBTQ+', description: 'Non-normative or non-conforming gender identity'),
  GenderOption(key: 'other', label: 'Prefer to Self-Describe', category: 'Other', description: 'Identity not listed above'),
];

class GenderSelectorBottomSheet extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<GenderOption> onSelect;
  final ScrollController? scrollController;

  const GenderSelectorBottomSheet({
    super.key,
    required this.selectedKey,
    required this.onSelect,
    this.scrollController,
  });

  static Future<GenderOption?> show(BuildContext context, String currentKey) {
    return showModalBottomSheet<GenderOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => GenderSelectorBottomSheet(
          selectedKey: currentKey,
          scrollController: scrollController,
          onSelect: (opt) => Navigator.pop(ctx, opt),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Select Gender Identity / लिंग चुनें",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "UR-Heart welcomes and supports all gender expressions unconditionally.",
                style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: kGenderSpectrum.length,
            itemBuilder: (ctx, idx) {
              final opt = kGenderSpectrum[idx];
              final isSelected = opt.key == selectedKey;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text(
                  opt.label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFF2E63) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  opt.description,
                  style: const TextStyle(color: Color(0xFF636375), fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFFFF2E63), size: 20)
                    : const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 20),
                onTap: () => onSelect(opt),
              );
            },
          ),
        ),
      ],
    );
  }
}
