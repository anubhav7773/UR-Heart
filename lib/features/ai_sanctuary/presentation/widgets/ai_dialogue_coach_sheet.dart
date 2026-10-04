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
  final String? partnerBio;
  final List<String>? partnerInterests;
  final List<Map<String, dynamic>>? recentMessages;

  const AiDialogueCoachSheet({
    super.key,
    required this.partnerName,
    required this.lastIncomingMessage,
    required this.onApplyReply,
    required this.isDark,
    this.partnerBio,
    this.partnerInterests,
    this.recentMessages,
  });

  static Future<void> show({
    required BuildContext context,
    required String partnerName,
    required String lastIncomingMessage,
    required ValueChanged<String> onApplyReply,
    required bool isDark,
    String? partnerBio,
    List<String>? partnerInterests,
    List<Map<String, dynamic>>? recentMessages,
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
        partnerBio: partnerBio,
        partnerInterests: partnerInterests,
        recentMessages: recentMessages,
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
  WingmanGuidanceResult? _guidanceResult;

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
    final result = await repo.getDialogueWingmanGuidance(
      partnerName: widget.partnerName,
      lastIncomingMessage: widget.lastIncomingMessage,
      userDraftReply: draft,
      partnerBio: widget.partnerBio,
      partnerInterests: widget.partnerInterests,
      recentMessages: widget.recentMessages,
    );

    if (mounted) {
      setState(() {
        _guidanceResult = result;
        _isLoading = false;
      });
    }
  }

  void _applySuggestion(String text) {
    HapticFeedback.mediumImpact();
    widget.onApplyReply(text);
    Navigator.of(context).pop();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard ✨'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark
        ? const Color(0xFF141C16)
        : const Color(0xFFFFFFFF);

    final cardBg = isDark
        ? const Color(0xFF1A261E)
        : const Color(0xFFF8F6F0);

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

    final borderStroke = isDark ? const Color(0xFF26382C) : const Color(0xFFE2E8F0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderStroke, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accentCoral, accentEmerald],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eva Dialogue Wingman ✨',
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Realtime Chemistry & Bonding Engine · Asiverticals',
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: mutedColor, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Last incoming message preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentEmerald.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, size: 20, color: accentCoral),
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

          const SizedBox(height: 12),

          // Scrollable Suggestions Body
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) ...[
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(accentCoral),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Analyzing profiles & synthesizing sparks...',
                              style: TextStyle(color: mutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_guidanceResult != null) ...[
                    // Coach Insight Card
                    if (_guidanceResult!.coachInsight.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentEmerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentEmerald.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 18, color: accentEmerald),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _guidanceResult!.coachInsight,
                                style: TextStyle(
                                  color: headlineColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Suggestion Cards (3 Modes)
                    Text(
                      'Ready-to-Send Suggestions (Tap to use):',
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...(_guidanceResult!.suggestions.map((item) {
                      Color badgeColor = accentCoral;
                      if (item.type == 'resonance') {
                        badgeColor = accentEmerald;
                      } else if (item.type == 'segue') {
                        badgeColor = const Color(0xFFE5A93C);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: badgeColor.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _applySuggestion(item.text),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.copy_rounded,
                                            size: 16, color: mutedColor),
                                        tooltip: 'Copy',
                                        onPressed: () =>
                                            _copyToClipboard(item.text),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: badgeColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () =>
                                            _applySuggestion(item.text),
                                        child: const Text('Use ⚡',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.text,
                                    style: TextStyle(
                                      color: headlineColor,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList()),
                  ],

                  const SizedBox(height: 8),

                  // Draft Reply Refiner
                  Text(
                    'Unsure about your draft? Polish it with Eva:',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _draftController,
                          style: TextStyle(color: headlineColor, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type your rough thought...',
                            hintStyle: TextStyle(color: mutedColor, fontSize: 12),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        onPressed: () {
                          if (_draftController.text.trim().isNotEmpty) {
                            HapticFeedback.lightImpact();
                            _fetchCoaching(_draftController.text);
                          }
                        },
                        child: const Text('Polish ✨',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
