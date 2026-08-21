import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Production Google Social Sign-In Button with official styling,
/// non-blocking loading state, and haptic feedback.
class GoogleAuthButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const GoogleAuthButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed();
              },
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF171822),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF252736), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google G Logo
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: const Color(0xFF4285F4),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
