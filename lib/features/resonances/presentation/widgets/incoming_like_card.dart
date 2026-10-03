import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../domain/resonance_models.dart';

class IncomingLikeCard extends StatelessWidget {
  final dynamic likeData;
  final bool isDark;
  final bool isSovereignUser;
  final VoidCallback onChatTriggered;

  const IncomingLikeCard({
    super.key,
    required this.likeData,
    required this.isDark,
    this.isSovereignUser = false,
    required this.onChatTriggered,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? DarkSanctuaryTokens.surface
        : LightSanctuaryTokens.surface;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final gold = isDark
        ? DarkSanctuaryTokens.goldAccent
        : LightSanctuaryTokens.goldAccent;

    final String fullName = likeData is Map
        ? (likeData['full_name'] as String? ?? 'Sanctuary Member')
        : (likeData.fullName as String? ?? 'Sanctuary Member');
    final int age = likeData is Map
        ? (likeData['age'] as int? ?? 23)
        : (likeData.age as int? ?? 23);
    final String photoUrl = likeData is Map
        ? (likeData['photo_url'] as String? ?? likeData['avatar_url'] as String? ?? '')
        : (likeData.photoUrl as String? ?? '');
    final int matchScore = likeData is Map
        ? (likeData['match_score'] as int? ?? 92)
        : (likeData.matchScore as int? ?? 92);
    final bool isDirect = likeData is Map
        ? (likeData['is_direct_letter'] as bool? ?? (likeData['swipe_type'] == 'direct'))
        : (likeData is IncomingLikeProfile ? (likeData as IncomingLikeProfile).isDirectLetter : false);

    final imageProvider = resolveSanctuaryImageProvider(photoUrl);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background Image (Blurred if not Sovereign)
            Positioned.fill(
              child: imageProvider != null
                  ? Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(pine),
                    )
                  : _buildFallback(pine),
            ),
            if (!isSovereignUser)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
                ),
              ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
            // Direct Letter Badge on top-left
            if (isDirect)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD36A42),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Text(
                    '💌 Direct Letter',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Sovereign Badge or Match Score Pill
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gold, width: 0.8),
                ),
                child: Text(
                  '$matchScore%',
                  style: TextStyle(color: gold, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Card Content & CTA
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSovereignUser ? '$fullName, $age' : 'Presence, $age',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Serif',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDirect
                        ? 'Sent you a direct letter'
                        : (isSovereignUser ? 'Liked you recently' : 'Unlock unmasked with Sovereign'),
                    maxLines: 1,
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDirect ? const Color(0xFFD36A42) : pine,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onChatTriggered,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isDirect ? '💌' : '⚡', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isDirect ? 'Direct Dialogue' : 'Spark Connection',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.15),
      child: Center(
        child: Icon(Icons.person, size: 48, color: accent.withValues(alpha: 0.4)),
      ),
    );
  }
}
