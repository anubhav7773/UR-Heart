import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Header component featuring UR-Heart branding, hardware security badge,
/// and animated Sign In / Sign Up toggle.
class AuthHeader extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onModeChanged;

  const AuthHeader({
    super.key,
    required this.isSignUp,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Glowing Brand Mark
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFF3366),
                  Color(0xFFE02856),
                  Color(0xFF0D0E15),
                ],
                stops: [0.0, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. App Name & Tagline
        const Text(
          'UR Heart',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isSignUp ? 'Join authentic connections across India' : 'Welcome back to your true match',
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 14),

        // 3. Encrypted Safety Badge (Antigravity Containment)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF13141F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF252736), width: 1),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald online pulse
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF34B7F1),
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Hardware-Locked Security (RSA-2048)',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Mode Toggle (Sign In / Sign Up)
        Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF13141F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF252736), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeChanged(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: !isSignUp ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: !isSignUp
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: !isSignUp ? Colors.white : AppTheme.textSecondaryColor,
                        fontSize: 14,
                        fontWeight: !isSignUp ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeChanged(true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isSignUp ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSignUp
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: isSignUp ? Colors.white : AppTheme.textSecondaryColor,
                        fontSize: 14,
                        fontWeight: isSignUp ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
