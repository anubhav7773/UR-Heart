import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../data/resonances_repository.dart';

class MutualConnectionTile extends StatelessWidget {
  final dynamic match;
  final MutualConnection? connection;
  final bool isDark;
  final VoidCallback onTap;

  const MutualConnectionTile({
    super.key,
    this.match,
    this.connection,
    required this.isDark,
    required this.onTap,
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

    final String fullName = _extractName();
    final int age = _extractAge();
    final String timeStr = _extractTime();
    final String snippet = _extractSnippet();

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26.0,
                      backgroundColor: pine.withValues(alpha: 0.12),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0] : 'S',
                        style: TextStyle(color: pine, fontWeight: FontWeight.bold, fontSize: 18.0),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10.0,
                        height: 10.0,
                        decoration: BoxDecoration(
                          color: pine,
                          shape: BoxShape.circle,
                          border: Border.all(color: surface, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$fullName, $age',
                            style: TextStyle(
                              fontFamily: 'Serif',
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.0,
                            ),
                          ),
                          Text(timeStr, style: TextStyle(color: subText, fontSize: 11.5)),
                        ],
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subText, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(Icons.chevron_right, color: subText.withValues(alpha: 0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _extractName() {
    if (connection != null) return connection?.fullName ?? '';
    if (match is Map) return (match['full_name'] as String? ?? 'Sanctuary Match');
    return 'Sanctuary Match';
  }

  int _extractAge() {
    if (connection != null) return connection?.age ?? 24;
    if (match is Map) return (match['age'] as int? ?? 24);
    return 24;
  }

  String _extractTime() {
    if (connection != null) return connection?.matchedTime ?? 'Just now';
    if (match is Map) return (match['matched_time'] as String? ?? 'Just now');
    return 'Just now';
  }

  String _extractSnippet() {
    if (connection != null) return connection?.lastSnippet ?? 'Mutual resonance established.';
    if (match is Map) return (match['last_snippet'] as String? ?? 'Mutual resonance established.');
    return 'Mutual resonance established.';
  }
}
