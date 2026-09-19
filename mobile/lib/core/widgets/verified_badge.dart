import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool showLabel;

  const VerifiedBadge({
    super.key,
    this.size = 18,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: showLabel ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero,
      decoration: showLabel
          ? BoxDecoration(
              color: const Color(0xFF06D6A0).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.35)),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            color: const Color(0xFF00B2FF), // Resonant Blue Verified Check
            size: size,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            const Text(
              "Verified",
              style: TextStyle(
                color: Color(0xFF00B2FF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
