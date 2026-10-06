import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/voice_spark_service.dart';

const List<String> kVoiceSparkPrompts = [
  'Mera favourite midnight snack / guilty pleasure...',
  'Sunday morning par meri ideal vibe...',
  'Ek aisi cheez jisko lekar main unapologetically passionate hoon...',
  'Don\'t date me if you can\'t handle...',
  'Meri favourite place jaha main ghanto baith sakta hoon...',
];

/// Luxury Modal for capturing 7-second Voice Spark ("Awaaz Jhooth Nahi Bolti")
class VoiceSparkRecordingModal extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final void Function(String voiceUrl, String prompt)? onSaved;
  final Future<void> Function(File audioFile, double durationSeconds, String prompt)? onRecorded;

  const VoiceSparkRecordingModal({
    super.key,
    this.initialPrompt,
    this.onSaved,
    this.onRecorded,
  });

  @override
  ConsumerState<VoiceSparkRecordingModal> createState() =>
      _VoiceSparkRecordingModalState();
}

enum _RecordPhase { idle, recording, preview, uploading }

class _VoiceSparkRecordingModalState
    extends ConsumerState<VoiceSparkRecordingModal>
    with SingleTickerProviderStateMixin {
  late String _selectedPrompt;
  _RecordPhase _phase = _RecordPhase.idle;
  int _secondsRemaining = 7;
  Timer? _countdownTimer;
  StreamSubscription<double>? _ampSub;
  double _currentAmplitude = 0.1;
  String? _recordedFilePath;
  bool _isPlayingPreview = false;
  late final AudioPlayer _previewPlayer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _selectedPrompt = widget.initialPrompt ?? kVoiceSparkPrompts.first;
    _previewPlayer = AudioPlayer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingPreview = false);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ampSub?.cancel();
    _previewPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    HapticFeedback.heavyImpact();
    final service = ref.read(voiceSparkServiceProvider);

    try {
      final path = await service.startRecording();
      setState(() {
        _phase = _RecordPhase.recording;
        _secondsRemaining = 7;
        _recordedFilePath = path;
      });

      _ampSub = service.amplitudeStream.listen((amp) {
        if (mounted) setState(() => _currentAmplitude = amp);
      });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;
        if (_secondsRemaining <= 1) {
          timer.cancel();
          await _stopRecording();
        } else {
          setState(() => _secondsRemaining--);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    _countdownTimer?.cancel();
    _ampSub?.cancel();
    HapticFeedback.mediumImpact();
    final service = ref.read(voiceSparkServiceProvider);
    final finalPath = await service.stopRecording();

    if (mounted) {
      setState(() {
        _phase = _RecordPhase.preview;
        _recordedFilePath = finalPath ?? _recordedFilePath;
        _currentAmplitude = 0.1;
      });
    }
  }

  Future<void> _togglePreview() async {
    if (_recordedFilePath == null) return;
    HapticFeedback.selectionClick();

    if (_isPlayingPreview) {
      await _previewPlayer.pause();
      setState(() => _isPlayingPreview = false);
    } else {
      await _previewPlayer.play(DeviceFileSource(_recordedFilePath!));
      setState(() => _isPlayingPreview = true);
    }
  }

  void _retakeRecording() {
    _previewPlayer.stop();
    setState(() {
      _phase = _RecordPhase.idle;
      _secondsRemaining = 7;
      _recordedFilePath = null;
      _isPlayingPreview = false;
    });
  }

  Future<void> _saveVoiceSpark() async {
    if (_recordedFilePath == null) return;
    _previewPlayer.stop();
    setState(() => _phase = _RecordPhase.uploading);

    final file = File(_recordedFilePath!);

    try {
      if (widget.onRecorded != null) {
        await widget.onRecorded!(file, 7.0, _selectedPrompt);
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final service = ref.read(voiceSparkServiceProvider);
      final res = await service.uploadVoiceSparkInstance(
        filePath: _recordedFilePath!,
        prompt: _selectedPrompt,
        duration: 7.0,
      );

      final url = res['voice_spark_url']?.toString() ?? '';
      widget.onSaved?.call(url, _selectedPrompt);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Voice Spark secured! Seekers can now hear your authentic aura.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _RecordPhase.preview);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;
    final bgColor = isDark ? const Color(0xFF131915) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF233128) : const Color(0xFFE5DFD5);
    final primaryCoral = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.accentTerracotta;
    final pine = isDark
        ? DarkSanctuaryTokens.secondaryPine
        : LightSanctuaryTokens.primaryPine;
    final textHeadline = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final textMuted = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -6)),
        ],
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: textMuted.withOpacity(0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryCoral.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.graphic_eq_rounded, size: 22, color: primaryCoral),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '7-Second Voice Spark',
                    style: AppTypography.titleH1.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: textHeadline,
                    ),
                  ),
                  Text(
                    'Awaaz jhooth nahi bolti · Pure authenticity',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Prompt Selector
          if (_phase == _RecordPhase.idle) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CHOOSE A PROMPT TO ANSWER:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kVoiceSparkPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final prompt = kVoiceSparkPrompts[idx];
                  final isSelected = prompt == _selectedPrompt;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPrompt = prompt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryCoral.withOpacity(0.15)
                            : (isDark ? const Color(0xFF1E2822) : const Color(0xFFF3EFEA)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? primaryCoral : cardBorder,
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? primaryCoral : textHeadline,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Active Prompt Display Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18221B) : const Color(0xFFF7F5F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, size: 20, color: primaryCoral),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPrompt,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: textHeadline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Central Visualizer & Action Area
          if (_phase == _RecordPhase.idle) ...[
            // Idle state: big glowing record button
            GestureDetector(
              onTap: _startRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.08);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [primaryCoral, const Color(0xFFE27D60)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryCoral.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 40),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to record (Max 7.0s)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted),
            ),
          ] else if (_phase == _RecordPhase.recording) ...[
            // Recording state: countdown progress & live waveform
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: (7 - _secondsRemaining) / 7.0,
                    strokeWidth: 6,
                    backgroundColor: cardBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryCoral),
                  ),
                ),
                GestureDetector(
                  onTap: _stopRecording,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryCoral,
                    ),
                    child: const Icon(Icons.stop_rounded, color: Colors.white, size: 42),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '0:0$_secondsRemaining remaining',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryCoral),
            ),
            const SizedBox(height: 12),
            // Live Waveform visualizer bars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(12, (index) {
                final barHeight = 8.0 + (_currentAmplitude * 28.0 * ((index % 3 + 1) / 3));
                return Container(
                  width: 4,
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: primaryCoral,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ] else if (_phase == _RecordPhase.preview) ...[
            // Preview state: listen before uploading
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play / Pause Preview
                GestureDetector(
                  onTap: _togglePreview,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pine,
                    ),
                    child: Icon(
                      _isPlayingPreview ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPlayingPreview ? 'Playing Preview...' : '7.0s Voice Note Ready',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textHeadline,
                      ),
                    ),
                    Text(
                      'Tap play to review your vibe',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _retakeRecording,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Re-record'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryCoral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saveVoiceSpark,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Save & Secure'),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Uploading spinner
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              'Securing your Voice Spark in Sanctuary...',
              style: TextStyle(fontSize: 13, color: textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
