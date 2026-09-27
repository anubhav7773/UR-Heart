import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/sanctuary_typography.dart';
import '../controllers/profile_setup_controller.dart';

class LiveVideoKycModal extends ConsumerStatefulWidget {
  const LiveVideoKycModal({super.key});

  @override
  ConsumerState<LiveVideoKycModal> createState() => _LiveVideoKycModalState();
}

class _LiveVideoKycModalState extends ConsumerState<LiveVideoKycModal> {
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
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        setState(() {
          _isRecording = false;
          _isProcessing = true;
        });

        // 3-second live selfie video binary simulation
        final mockBytes = List<int>.filled(50000, 1);
        await ref
            .read(profileSetupControllerProvider.notifier)
            .executeVideoKyc(videoBytes: mockBytes);

        if (mounted) {
          setState(() => _isProcessing = false);
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final bg = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final secondary = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final accent = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.sanctuaryPine;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.videocam_rounded, color: accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              '3-Second Live Video KYC',
              style: SanctuaryTypography.titleH2.copyWith(color: primary, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Gently turn your head slightly left and right. Liveness verification takes 3 seconds.',
              textAlign: TextAlign.center,
              style: SanctuaryTypography.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: _isRecording
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 32),
                          const SizedBox(height: 8),
                          Text('Recording... ${_countdownSeconds}s', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : _isProcessing
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: accent),
                              const SizedBox(height: 12),
                              Text('Verifying biometric liveness...', style: TextStyle(color: secondary, fontSize: 12)),
                            ],
                          )
                        : Icon(Icons.face_retouching_natural, color: secondary.withValues(alpha: 0.4), size: 64),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_isRecording || _isProcessing) ? null : _startRecording,
                child: Text(
                  _isRecording ? 'Capturing Video...' : 'Begin 3s Live Verification',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
