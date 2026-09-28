import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

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
        ? (likeData['photo_url'] as String? ?? '')
        : (likeData.photoUrl as String? ?? '');
    final int matchScore = likeData is Map
        ? (likeData['match_score'] as int? ?? 92)
        : (likeData.matchScore as int? ?? 92);

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
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
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
                    isSovereignUser ? 'Liked you recently' : 'Unlock unmasked with Sovereign',
                    maxLines: 1,
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pine,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onChatTriggered,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('⚡', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text(
                            'Spark Direct Connection',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
