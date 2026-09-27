import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 100% STRICTLY TEXT-ONLY bottom input bar for Screen 9
/// Explicitly forbids media, camera, mic, sticker, or attachment icons.
class DialogueInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isDark;

  const DialogueInputBar({
    super.key,
    required this.onSend,
    required this.isDark,
  });

  @override
  State<DialogueInputBar> createState() => _DialogueInputBarState();
}

class _DialogueInputBarState extends State<DialogueInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _canSend) {
        setState(() => _canSend = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final borderColor = widget.isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final inputBg = widget.isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;
    final inputBorder = widget.isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;
    final textColor = widget.isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final hintColor = widget.isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final sendActiveColor = widget.isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;
    final sendDisabledColor = widget.isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120.0),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(color: inputBorder, width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.bodyStandard.copyWith(color: textColor, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Write a heartfelt message...',
                    hintStyle: AppTypography.bodySmall.copyWith(color: hintColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            InkWell(
              onTap: _canSend ? _handleSend : null,
              borderRadius: BorderRadius.circular(22.0),
              child: Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: _canSend ? sendActiveColor : sendDisabledColor,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
