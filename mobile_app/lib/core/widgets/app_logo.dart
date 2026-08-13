import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AppLogo({
    super.key,
    this.size = 80.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Glowing Aura
        if (showGlow)
          Container(
            width: size * 1.3,
            height: size * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.08,
                ),
              ],
            ),
          ),

        // Glowing Gradient Heart Container
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFFE91E63), // Rose Crimson
                Color(0xFFFF4081), // Glowing Pink
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      ],
    );
  }
}
