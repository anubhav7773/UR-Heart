import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/ai_sanctuary_repository.dart';

class AiGrievanceAssistantSheet extends ConsumerStatefulWidget {
  final String offenderName;
  final ValueChanged<String>? onCategorySuggested;
  final bool isDark;

  const AiGrievanceAssistantSheet({
    super.key,
    required this.offenderName,
    this.onCategorySuggested,
    required this.isDark,
  });

  static Future<void> show({
    required BuildContext context,
    required String offenderName,
    ValueChanged<String>? onCategorySuggested,
    required bool isDark,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiGrievanceAssistantSheet(
        offenderName: offenderName,
        onCategorySuggested: onCategorySuggested,
        isDark: isDark,
      ),
    );
  }

  @override
  ConsumerState<AiGrievanceAssistantSheet> createState() =>
      _AiGrievanceAssistantSheetState();
}

class _AiGrievanceAssistantSheetState
    extends ConsumerState<AiGrievanceAssistantSheet> {
  final TextEditingController _narrativeController = TextEditingController();
  bool _isLoading = false;
  String _guidance = '';

  @override
  void dispose() {
    _narrativeController.dispose();
    super.dispose();
  }

  Future<void> _analyzeIncident() async {
    final text = _narrativeController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final repo = ref.read(aiSanctuaryRepositoryProvider);
    final result = await repo.assistGrievanceFiling(
      offenderName: widget.offenderName,
      userNarrative: text,
    );

    if (mounted) {
      setState(() {
        _guidance = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark
        ? const Color(0xFF16231C)
        : const Color(0xFFFFFFFF);

    final cardBg = isDark
        ? const Color(0xFF1E2B23)
        : const Color(0xFFF7F5F0);

    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final alertCoral = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    final accentEmerald = isDark
        ? const Color(0xFF4E9F76)
        : const Color(0xFF2E6B4F);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 14,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4035) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alertCoral.withOpacity(0.15),
                ),
                child: Icon(Icons.shield_rounded, size: 18, color: alertCoral),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eva Safety & Grievance Concierge',
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Statutory Reporting Assistant by Asiverticals',
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: mutedColor, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Feeling confused or distressed? Tell Eva what happened in your own words. '
            'She will guide you through IT Rules 2021 statutory reporting with calm empathy.',
            style: TextStyle(color: mutedColor, fontSize: 12, height: 1.35),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _narrativeController,
            maxLines: 3,
            style: TextStyle(color: headlineColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. He sent unsolicited messages and refused to respect my boundary...',
              hintStyle: TextStyle(color: mutedColor, fontSize: 12.5),
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF283A2E) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: alertCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isLoading ? 'Eva is analyzing...' : 'Analyze & Guide My Report',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _isLoading ? null : _analyzeIncident,
            ),
          ),

          if (_guidance.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentEmerald.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 14, color: accentEmerald),
                      const SizedBox(width: 6),
                      Text(
                        'Eva Guidance & IT Rules 2021 Advice:',
                        style: TextStyle(
                          color: headlineColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _guidance,
                    style: TextStyle(color: headlineColor, fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
