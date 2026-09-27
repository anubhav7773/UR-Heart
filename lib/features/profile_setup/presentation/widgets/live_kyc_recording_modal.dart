import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// Modal dialog handling the 3-second live selfie video recording and Groq Vision KYC evaluation
class LiveKycRecordingModal extends ConsumerStatefulWidget {
  const LiveKycRecordingModal({super.key});

  @override
  ConsumerState<LiveKycRecordingModal> createState() =>
      _LiveKycRecordingModalState();
}

class _LiveKycRecordingModalState extends ConsumerState<LiveKycRecordingModal> {
  bool _isRecording = false;
  int _countdownSeconds = 3;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _countdownSeconds = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRecording = false;
          _isProcessing = true;
        });

        // Simulate 3-second video binary generation (H.264/MP4 bytes)
        final mockVideoBytes = List<int>.filled(50000, 1);
        await ref
            .read(profileSetupControllerProvider.notifier)
            .executeVideoKyc(videoBytes: mockVideoBytes);

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final bodyColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;

    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final verifiedTeal = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56.0,
              height: 56.0,
              decoration: BoxDecoration(
                color: verifiedTeal.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: verifiedTeal, width: 1.5),
              ),
              child: Center(
                child: Icon(Icons.verified, color: verifiedTeal, size: 28.0),
              ),
            ),
            const SizedBox(height: 14.0),
            Text(
              'Claim Verified Crest',
              style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 20.0),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Complete a gentle 3-second live video reflection to confirm your authenticity. Evaluated ephemerally by Groq AI and purged immediately.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: bodyColor, height: 1.4),
            ),
            const SizedBox(height: 20.0),
            // Live Camera View Simulation Container
            Container(
              height: 160.0,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: accentColor.withOpacity(0.4)),
              ),
              child: Center(
                child: _isProcessing
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: accentColor, strokeWidth: 2.5),
                          const SizedBox(height: 10.0),
                          Text(
                            'Groq Vision Llama-3.2 evaluating...',
                            style: AppTypography.caption.copyWith(color: titleColor),
                          ),
                        ],
                      )
                    : _isRecording
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.red, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_countdownSeconds',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'Gently tilt your head or smile',
                                style: AppTypography.caption.copyWith(color: titleColor),
                              ),
                            ],
                          )
                        : Icon(Icons.videocam_outlined, size: 48.0, color: accentColor),
              ),
            ),
            const SizedBox(height: 20.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRecording || _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecording || _isProcessing ? null : _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: Text(
                      _isRecording ? 'Recording...' : 'Start (3s ✨)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
