import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/dark_sanctuary_tokens.dart';
import '../theme/light_sanctuary_tokens.dart';

/// Web Mindful Sponsor Reflection Dialog
/// Provides Web & Desktop users a peaceful, 15-second mindful reflection
/// to earn tokens fairly without requiring native mobile AdMob SDK.
class WebMindfulSponsorDialog extends StatefulWidget {
  final String adType;

  const WebMindfulSponsorDialog({
    super.key,
    required this.adType,
  });

  @override
  State<WebMindfulSponsorDialog> createState() => _WebMindfulSponsorDialogState();
}

class _WebMindfulSponsorDialogState extends State<WebMindfulSponsorDialog> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 15;
  Timer? _timer;
  late AnimationController _pulseController;
  bool _isCompleted = false;

  final List<String> _mindfulPrompts = [
    'Take a deep breath in... and gently release.',
    'Sanctuary is sustained by conscious attention.',
    'Honoring genuine human connection over algorithms.',
    'Cultivating clarity, patience, and presence.',
  ];

  int _promptIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
          if (_secondsRemaining % 4 == 0) {
            _promptIndex = (_promptIndex + 1) % _mindfulPrompts.length;
          }
        });
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isCompleted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final sub = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;

    final double progress = (15 - _secondsRemaining) / 15.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: pine.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.spa_rounded, color: gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SANCTUARY REFLECTION',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: sub, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.06);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(_isCompleted ? gold : pine),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isCompleted) ...[
                          Text(
                            '$_secondsRemaining',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Serif',
                              color: primary,
                            ),
                          ),
                          Text(
                            'seconds',
                            style: TextStyle(fontSize: 11, color: sub),
                          ),
                        ] else ...[
                          Icon(Icons.check_circle_rounded, color: gold, size: 40),
                          const SizedBox(height: 4),
                          Text(
                            'Blessed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _isCompleted
                      ? 'Mindful reflection complete. Your sanctuary token is ready.'
                      : _mindfulPrompts[_promptIndex],
                  key: ValueKey<int>(_isCompleted ? 99 : _promptIndex),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: primary,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCompleted ? gold : pine.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isCompleted ? () => Navigator.of(context).pop(true) : null,
                  child: Text(
                    _isCompleted ? 'Claim Sanctuary Token ➔' : 'Reflecting...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _isCompleted ? (isDark ? Colors.black : Colors.white) : Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
