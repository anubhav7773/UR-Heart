import 'package:flutter/material.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// 100% Text-Only Chat Input Bar with local NLP privacy gatekeeper
class TextOnlyChatInputBar extends StatefulWidget {
  final bool isDark;
  final void Function(String message) onSendMessage;
  final void Function(String violation)? onViolation;
  final TextEditingController? controller;

  const TextOnlyChatInputBar({
    super.key,
    required this.isDark,
    required this.onSendMessage,
    this.onViolation,
    this.controller,
  });

  @override
  State<TextOnlyChatInputBar> createState() => _TextOnlyChatInputBarState();
}

class _TextOnlyChatInputBarState extends State<TextOnlyChatInputBar> {
  late final TextEditingController _textController;
  bool _isInternalController = false;
  bool _canSend = false;

  static const Map<String, String> _hindiDigits = {
    'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'paanch': '5',
    'chhe': '6', 'saat': '7', 'aath': '8', 'nau': '9', 'shunya': '0', 'zero': '0'
  };

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _textController = widget.controller!;
    } else {
      _textController = TextEditingController();
      _isInternalController = true;
    }
    _canSend = _textController.text.trim().isNotEmpty;
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _canSend && mounted) {
      setState(() => _canSend = hasText);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    if (_isInternalController) {
      _textController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final surfaceMuted = widget.isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final primaryText = widget.isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = widget.isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = widget.isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: surfaceMuted, width: 1.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: surfaceMuted,
                borderRadius: BorderRadius.circular(22.0),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: primaryText, fontSize: 14.0, height: 1.35),
                onChanged: (val) {
                  final hasText = val.trim().isNotEmpty;
                  if (hasText != _canSend) {
                    setState(() => _canSend = hasText);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Write a heartfelt message...',
                  hintStyle: TextStyle(color: subText.withValues(alpha: 0.7), fontSize: 13.0),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              color: _canSend ? pine : surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: _canSend ? Colors.white : subText,
                size: 20.0,
              ),
              onPressed: _canSend ? _handleSendAttempt : null,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendAttempt() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    // 1. Client-Side NLP Contact Sanitizer Inspection
    final violation = _inspectForContactViolations(rawText);
    if (violation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(violation),
          backgroundColor: widget.isDark ? DarkSanctuaryTokens.dangerBorder : LightSanctuaryTokens.dangerBorder,
          duration: const Duration(seconds: 4),
        ),
      );
      widget.onViolation?.call(violation);
      return;
    }

    widget.onSendMessage(rawText);
    _textController.clear();
    setState(() => _canSend = false);
  }

  String? _inspectForContactViolations(String text) {
    final lower = text.toLowerCase();
    final stripped = lower.replaceAll(RegExp(r'[\s\.\-_/\\,;:*+~]'), '');

    // 10-Digit Indian Mobile Numbers (6-9 prefix)
    if (RegExp(r'(?:\+?91)?[6-9]\d{9}').hasMatch(stripped)) {
      return 'Direct phone numbers are shielded. Unmask via Sacred Contact Bridge.';
    }

    // Transliterated Hindi digits
    String transliterated = lower;
    _hindiDigits.forEach((word, digit) {
      transliterated = transliterated.replaceAll(RegExp(r'\b' + word + r'\b'), digit);
    });
    final transStripped = transliterated.replaceAll(RegExp(r'[\s\.\-_]'), '');
    if (RegExp(r'[6-9]\d{9}').hasMatch(transStripped)) {
      return 'Spelled-out phone numbers cannot be shared in open dialogue.';
    }

    // Social Handles & Links
    if (RegExp(r'(?:wa\.me|t\.me|instagram\.com|snapchat\.com|ig:|snap:|tg:|@[a-zA-Z0-9_]{3,})').hasMatch(lower)) {
      return 'Direct handles and social links are prohibited. Use the Sacred Bridge.';
    }

    // UPI Identifiers
    if (RegExp(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}').hasMatch(lower)) {
      return 'Payment identifiers and UPI addresses are prohibited in sanctuary.';
    }

    return null;
  }
}
