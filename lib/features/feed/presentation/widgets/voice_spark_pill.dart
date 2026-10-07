import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Glassmorphic Voice Spark Audio Pill embedded in Candidate Feed Cards
/// and Seeker Profile Details ("Awaaz Jhooth Nahi Bolti").
class VoiceSparkPill extends StatefulWidget {
  final String voiceUrl;
  final String? prompt;
  final double duration;
  final bool isDark;

  const VoiceSparkPill({
    super.key,
    required this.voiceUrl,
    this.prompt,
    this.duration = 7.0,
    required this.isDark,
  });

  @override
  State<VoiceSparkPill> createState() => _VoiceSparkPillState();
}

class _VoiceSparkPillState extends State<VoiceSparkPill>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveAnimController;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _stateSub = _player.onPlayerStateChanged.listen(
      (state) {
        if (!mounted) return;
        if (state == PlayerState.playing) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
          _waveAnimController.repeat(reverse: true);
        } else {
          setState(() {
            _isPlaying = false;
            _isLoading = false;
          });
          _waveAnimController.stop();
        }
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[VoiceSparkPill] Player state stream error: $error');
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
        _waveAnimController.stop();
      },
    );

    _completeSub = _player.onPlayerComplete.listen(
      (_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
        _waveAnimController.stop();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[VoiceSparkPill] Player complete stream error: $error');
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
        _waveAnimController.stop();
      },
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _completeSub?.cancel();
    _waveAnimController.dispose();
    try {
      _player.stop();
    } catch (_) {}
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final cleanUrl = widget.voiceUrl.trim();
    if (cleanUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No voice snippet available for this profile.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid voice snippet audio link.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    HapticFeedback.selectionClick();
    if (_isPlaying) {
      try {
        await _player.pause();
      } catch (e) {
        debugPrint('[VoiceSparkPill] Error pausing audio: $e');
      }
    } else {
      setState(() => _isLoading = true);
      try {
        await _player.stop();
        await _player.play(UrlSource(cleanUrl));
      } catch (e, stack) {
        debugPrint('[VoiceSparkPill] Audio play error: $e\n$stack');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isLoading = false;
          });
          _waveAnimController.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not play voice snippet. Please try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.voiceUrl.trim().isEmpty) return const SizedBox.shrink();

    final pillBg = widget.isDark
        ? const Color(0xFF1B2620).withOpacity(0.85)
        : const Color(0xFFFAF7F2).withOpacity(0.95);

    final borderColor = widget.isDark
        ? const Color(0xFF2E3E34)
        : const Color(0xFFE2DDD5);

    final coral = widget.isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.accentTerracotta;

    final primaryText = widget.isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedText = widget.isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final promptText = widget.prompt?.trim().isNotEmpty == true
        ? widget.prompt!.trim()
        : 'Sunlo meri authentic vibe...';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPlaying ? coral.withOpacity(0.6) : borderColor,
          width: _isPlaying ? 1.4 : 1.0,
        ),
        boxShadow: [
          if (_isPlaying)
            BoxShadow(
              color: coral.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _toggleAudio,
          splashColor: coral.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Play / Pause Circle
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [coral, const Color(0xFFE07A5F)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: coral.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Prompt snippet & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, size: 14, color: coral),
                          const SizedBox(width: 5),
                          Text(
                            'VOICE SPARK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: coral,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.duration.toInt()}s',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        promptText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Animated Equalizer Waveform Bars
                AnimatedBuilder(
                  animation: _waveAnimController,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(6, (i) {
                        double height = 6.0;
                        if (_isPlaying) {
                          final sine = math.sin(
                            (_waveAnimController.value * 2 * math.pi) + (i * 0.8),
                          );
                          height = 6.0 + (sine.abs() * 16.0);
                        }
                        return Container(
                          width: 3.2,
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: _isPlaying ? coral : mutedText.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
