import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/dark_sanctuary_tokens.dart';
import '../theme/light_sanctuary_tokens.dart';

/// Ultra-Premium Responsive Frame for UR-Heart
/// - On mobile/tablets (< 600px width): Renders 100% edge-to-edge native fullscreen.
/// - On laptop & desktop browsers (>= 600px width): Renders inside a luxury modern
///   smartphone mockup with titanium micro-bezel, dynamic island pill, multi-layer
///   ambient shadows, and theme-adaptive atmospheric backdrop.
class ResponsiveDesktopFrame extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const ResponsiveDesktopFrame({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Native mobile phone screen or small window -> edge-to-edge
        if (constraints.maxWidth < 600) {
          return child;
        }

        // Desktop / Laptop presentation
        final outerBg = isDark ? const Color(0xFF090B10) : const Color(0xFFEAE7E1);
        final bezelColor = isDark ? const Color(0xFF232A34) : const Color(0xFFD4CFCA);
        final accentGlow = isDark ? const Color(0x227952F5) : const Color(0x18D4AF37);
        final secondaryGlow = isDark ? const Color(0x1AFF2E7E) : const Color(0x14D97746);
        final textCol = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
        final mutedCol = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;

        final availableHeight = constraints.maxHeight;
        final cardHeight = math.min(availableHeight - 40.0, 890.0);
        const cardWidth = 430.0;

        return Scaffold(
          backgroundColor: outerBg,
          body: Stack(
            children: [
              // Ambient Decorative Atmospheric Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: outerBg,
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -0.7),
                      radius: 1.2,
                      colors: [
                        secondaryGlow,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.7, 0.8),
                      radius: 1.4,
                      colors: [
                        accentGlow,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Desktop Header Branding (visible when screen has comfortable width)
              if (constraints.maxWidth >= 850)
                Positioned(
                  top: 24,
                  left: 36,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2E7E), Color(0xFF7952F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2E7E).withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'UR-HEART',
                            style: TextStyle(
                              fontFamily: 'Serif',
                              color: textCol,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          Text(
                            'Mindful Dating Sanctuary · Web Edition',
                            style: TextStyle(
                              color: mutedCol,
                              fontSize: 11.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Centered Luxury Smartphone Device Frame
              Center(
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  margin: const EdgeInsets.symmetric(vertical: 20.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(42.0),
                    border: Border.all(
                      color: bezelColor,
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.75)
                            : const Color(0x3D242B28),
                        blurRadius: 40.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 16.0),
                      ),
                      BoxShadow(
                        color: isDark
                            ? const Color(0x1F7952F5)
                            : const Color(0x1F2D5A43),
                        blurRadius: 24.0,
                        spreadRadius: -4.0,
                        offset: const Offset(0, 8.0),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(38.0),
                    child: Stack(
                      children: [
                        // Active Screen Child
                        Positioned.fill(
                          child: child,
                        ),

                        // Realistic Top Dynamic Island Notch Pill
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 100,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Camera lens
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A1A2E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Speaker pill
                                  Container(
                                    width: 36,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C2C38),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
