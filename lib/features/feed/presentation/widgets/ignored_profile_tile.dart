import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

class IgnoredProfileTile extends StatelessWidget {
  final dynamic candidate;
  final bool isDark;
  final VoidCallback onRevisitTap;

  const IgnoredProfileTile({
    super.key,
    required this.candidate,
    required this.isDark,
    required this.onRevisitTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? DarkSanctuaryTokens.surface
        : LightSanctuaryTokens.surface;
    final primaryText = isDark
        ? DarkSanctuaryTokens.primaryText
        : LightSanctuaryTokens.primaryText;
    final subText = isDark
        ? DarkSanctuaryTokens.secondaryText
        : LightSanctuaryTokens.secondaryText;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;

    final String fullName = candidate is Map
        ? (candidate['full_name'] as String? ?? 'Sanctuary Member')
        : (candidate.fullName as String? ?? 'Sanctuary Member');
    final int age = candidate is Map
        ? (candidate['age'] as int? ?? 24)
        : (candidate.age as int? ?? 24);
    final String location = candidate is Map
        ? (candidate['location_name'] as String? ?? 'Ayodhya')
        : (candidate.locationName as String? ?? 'Ayodhya');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: pine.withValues(alpha: 0.12),
            child: Text(
              fullName.isNotEmpty ? fullName[0] : 'S',
              style: TextStyle(color: pine, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fullName, $age',
                  style: TextStyle(
                    fontFamily: 'Serif',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location,
                  style: TextStyle(fontSize: 12, color: subText),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: pine,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh, size: 15, color: Colors.white),
            label: const Text(
              'Revisit',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: onRevisitTap,
          ),
        ],
      ),
    );
  }
}
