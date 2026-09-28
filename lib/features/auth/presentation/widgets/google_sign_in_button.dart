import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';

/// Custom Painter drawing the official multi-colored Google "G" emblem
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w / 2;

    // Google Colors
    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final Rect fullRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Red sector (top)
    final Path redPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(fullRect, -2.356, 1.57, false) // -135 deg to -45 deg
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Blue sector (right & crossbar)
    final Path bluePath = Path()
      ..moveTo(cx, cy)
      ..arcTo(fullRect, -0.785, 1.57, false) // -45 deg to +45 deg
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green sector (bottom)
    final Path greenPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(fullRect, 0.785, 1.57, false) // +45 deg to +135 deg
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow sector (left)
    final Path yellowPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(fullRect, 2.356, 1.57, false) // +135 deg to +225 deg
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Inner cutout
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.58, whitePaint);

    // Center horizontal bar for "G"
    final Rect barRect = Rect.fromLTRB(cx, cy - r * 0.22, cx + r, cy + r * 0.22);
    canvas.drawRect(barRect, bluePaint);

    // Right-top cutout to shape the "G"
    final Path cutPath = Path()
      ..moveTo(cx, cy - r * 0.22)
      ..lineTo(cx + r, cy - r * 0.22)
      ..lineTo(cx + r, cy - r)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(cutPath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Vector Widget for the Google Logo Icon
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.95,
          height: size * 0.95,
          child: const CustomPaint(
            painter: GoogleLogoPainter(),
          ),
        ),
      ),
    );
  }
}

/// 100% Production-Grade Google One Tap / Sign-In Button
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDark;
  final String text;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.isDark = true,
    this.text = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E242B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF333B44) : const Color(0xFFDADCE0);
    final textColor = isDark ? const Color(0xFFE8EAED) : const Color(0xFF3C4043);

    return SizedBox(
      width: double.infinity,
      height: 48.0,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          elevation: isDark ? 0 : 0.5,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 22.0,
                height: 22.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? const Color(0xFF8AB4F8) : const Color(0xFF4285F4),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoIcon(size: 20.0),
                  const SizedBox(width: 12.0),
                  Text(
                    text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
