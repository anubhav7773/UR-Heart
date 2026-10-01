import 'package:flutter/material.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../domain/resonance_models.dart';

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
    final String photoUrl = _extractPhotoUrl();
    final bool isDirect = _isDirectLetter();
    final imageProvider = resolveSanctuaryImageProvider(photoUrl);


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
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Text(
                              fullName.isNotEmpty ? fullName[0] : 'S',
                              style: TextStyle(color: pine, fontWeight: FontWeight.bold, fontSize: 18.0),
                            )
                          : null,
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
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$fullName, $age',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Serif',
                                      color: primaryText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDirect
                                        ? const Color(0xFFD36A42).withValues(alpha: 0.15)
                                        : pine.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isDirect ? '💌 Letter' : '💫 Mutual',
                                    style: TextStyle(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w700,
                                      color: isDirect ? const Color(0xFFD36A42) : pine,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(timeStr, style: TextStyle(color: subText, fontSize: 11.0)),
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
    if (connection != null) return connection!.fullName;
    if (match is MutualConnection) return (match as MutualConnection).fullName;
    if (match is Map) return (match['full_name'] as String? ?? match['name'] as String? ?? 'Sanctuary Match');
    return 'Sanctuary Match';
  }

  int _extractAge() {
    if (connection != null) return connection!.age;
    if (match is MutualConnection) return (match as MutualConnection).age;
    if (match is Map) return (match['age'] as int? ?? 24);
    return 24;
  }

  String _extractPhotoUrl() {
    if (connection != null) return connection!.photoUrl;
    if (match is MutualConnection) return (match as MutualConnection).photoUrl;
    if (match is Map) return (match['photo_url'] as String? ?? match['avatar_url'] as String? ?? '');
    return '';
  }

  String _extractTime() {
    if (connection != null) return connection!.matchedTime;
    if (match is MutualConnection) return (match as MutualConnection).matchedTime;
    if (match is Map) return (match['matched_time'] as String? ?? 'Just now');
    return 'Just now';
  }

  String _extractSnippet() {
    if (connection != null) return connection!.lastSnippet;
    if (match is MutualConnection) return (match as MutualConnection).lastSnippet;
    if (match is Map) return (match['last_snippet'] as String? ?? 'Mutual resonance established.');
    return 'Mutual resonance established.';
  }

  bool _isDirectLetter() {
    if (connection != null) return connection!.isDirectLetter;
    if (match is MutualConnection) return (match as MutualConnection).isDirectLetter;
    if (match is Map) {
      return (match['is_direct_letter'] as bool? ??
          (match['category_tag']?.toString().toLowerCase().contains('direct') ?? false));
    }
    return false;
  }
}
