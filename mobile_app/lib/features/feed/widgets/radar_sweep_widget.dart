import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class RadarSweepWidget extends StatefulWidget {
  final double size;

  const RadarSweepWidget({
    super.key,
    this.size = 180.0,
  });

  @override
  State<RadarSweepWidget> createState() => _RadarSweepWidgetState();
}

class _RadarSweepWidgetState extends State<RadarSweepWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding Concentric Radar Rings
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RadarRingsPainter(_controller.value),
              );
            },
          ),

          // Center Glyph: Elevated Coral Heart on Dark Slate
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface_interactive,
              border: Border.all(
                color: AppTheme.border_subtle,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent_primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.favorite_rounded,
                color: AppTheme.accent_primary,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarRingsPainter extends CustomPainter {
  final double progress;

  _RadarRingsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    const ringCount = 3;

    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + (i / ringCount)) % 1.0;
      final curvedProgress = Curves.easeOut.transform(ringProgress);

      // Smoothly scale from 0.4 to 1.2
      final currentRadius = maxRadius * (0.4 + (0.8 * curvedProgress));
      // Fade opacity from 0.6 down to 0.0
      final opacity = ((1.0 - ringProgress) * 0.6).clamp(0.0, 1.0);

      if (opacity <= 0.001) continue;

      final paintStroke = Paint()
        ..color = AppTheme.accent_primary.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final paintFill = Paint()
        ..color = AppTheme.accent_primary.withValues(alpha: opacity * 0.12)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, currentRadius, paintFill);
      canvas.drawCircle(center, currentRadius, paintStroke);
    }
  }

  @override
  bool shouldRepaint(_RadarRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
