import 'package:flutter/material.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Cryptographic Bridge Stage Gatekeeper for Audio Whisper and Media (ACT-18 & ACT-19 Fix)
/// Stage 1: Strictly text-only dialogue
/// Stage 2: Audio Whisper call unlocked
/// Stage 3: Direct Encrypted Media sharing unlocked
class ChatDetailActionBar extends StatelessWidget {
  final int bridgeStage; // 1, 2, or 3
  final bool isDark;
  final VoidCallback onStartAudioCall;
  final VoidCallback onSendMedia;

  const ChatDetailActionBar({
    super.key,
    required this.bridgeStage,
    required this.isDark,
    required this.onStartAudioCall,
    required this.onSendMedia,
  });

  @override
  Widget build(BuildContext context) {
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final sub = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;

    final canAudio = bridgeStage >= 2;
    final canMedia = bridgeStage >= 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio Whisper Call Action (ACT-18 Fix)
        IconButton(
          tooltip: canAudio ? 'Start Audio Whisper' : 'Audio Whisper Locked (Stage 2 required)',
          icon: Icon(
            canAudio ? Icons.phone_in_talk_outlined : Icons.phone_locked_outlined,
            color: canAudio ? pine : sub.withValues(alpha: 0.4),
            size: 20,
          ),
          onPressed: () {
            if (canAudio) {
              onStartAudioCall();
            } else {
              _showStageRequirementDialog(
                context,
                title: 'Audio Whisper Locked',
                message: 'Intimate audio reflections unlock upon completing Sacred Bridge Stage 2.',
              );
            }
          },
        ),

        // Encrypted Media Share Action (ACT-19 Fix)
        IconButton(
          tooltip: canMedia ? 'Share Encrypted Media' : 'Media Sharing Shielded (Stage 3 required)',
          icon: Icon(
            canMedia ? Icons.image_outlined : Icons.lock_clock_outlined,
            color: canMedia ? pine : sub.withValues(alpha: 0.4),
            size: 20,
          ),
          onPressed: () {
            if (canMedia) {
              onSendMedia();
            } else {
              _showStageRequirementDialog(
                context,
                title: 'Media Sharing Shielded',
                message: 'Moments sharing unlocks only upon mutual Stage 3 contact unmasking.',
              );
            }
          },
        ),
      ],
    );
  }

  void _showStageRequirementDialog(BuildContext context, {required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}
