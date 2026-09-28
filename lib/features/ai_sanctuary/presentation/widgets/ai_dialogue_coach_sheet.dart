import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/ai_sanctuary_repository.dart';

class AiDialogueCoachSheet extends ConsumerStatefulWidget {
  final String partnerName;
  final String lastIncomingMessage;
  final ValueChanged<String> onApplyReply;
  final bool isDark;

  const AiDialogueCoachSheet({
    super.key,
    required this.partnerName,
    required this.lastIncomingMessage,
    required this.onApplyReply,
    required this.isDark,
  });

  static Future<void> show({
    required BuildContext context,
    required String partnerName,
    required String lastIncomingMessage,
    required ValueChanged<String> onApplyReply,
    required bool isDark,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiDialogueCoachSheet(
        partnerName: partnerName,
        lastIncomingMessage: lastIncomingMessage,
        onApplyReply: onApplyReply,
        isDark: isDark,
      ),
    );
  }

  @override
  ConsumerState<AiDialogueCoachSheet> createState() =>
      _AiDialogueCoachSheetState();
}

class _AiDialogueCoachSheetState extends ConsumerState<AiDialogueCoachSheet> {
  final TextEditingController _draftController = TextEditingController();
  bool _isLoading = true;
  String _adviceResult = '';

  @override
  void initState() {
    super.initState();
    _fetchCoaching();
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoaching([String? draft]) async {
    setState(() => _isLoading = true);
    final repo = ref.read(aiSanctuaryRepositoryProvider);
    final advice = await repo.getDialogueCoaching(
      partnerName: widget.partnerName,
      lastIncomingMessage: widget.lastIncomingMessage,
      userDraftReply: draft,
    );

    if (mounted) {
      setState(() {
        _adviceResult = advice;
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

    final accentCoral = isDark
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
                  gradient: LinearGradient(colors: [accentCoral, accentEmerald]),
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eva Dialogue Wingman',
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Authentic communication coach by Asiverticals',
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

          const SizedBox(height: 12),

          // Last incoming message preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentEmerald.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 18, color: accentCoral),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.partnerName}: "${widget.lastIncomingMessage}"',
                    style: TextStyle(
                      color: headlineColor,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Advice / Suggestion Box
          Text(
            'Mindful Guidance & Reply Ideas:',
            style: TextStyle(
              color: headlineColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          if (_isLoading)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accentCoral),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Eva is crafting mindful suggestions...',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF283A2E) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: SelectableText(
                _adviceResult,
                style: TextStyle(
                  color: headlineColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Draft Reply tester
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _draftController,
                  style: TextStyle(color: headlineColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Draft a reply for Eva to polish...',
                    hintStyle: TextStyle(color: mutedColor, fontSize: 12.5),
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _fetchCoaching(_draftController.text);
                },
                child: const Text('Polish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
