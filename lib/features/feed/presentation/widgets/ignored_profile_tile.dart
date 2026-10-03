import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import '../../domain/candidate_profile.dart';

class IgnoredProfileTile extends StatelessWidget {
  final dynamic candidate;
  final bool isDark;
  final VoidCallback onRevisitTap;
  final VoidCallback? onProfileTap;
  final bool isRestoring;

  const IgnoredProfileTile({
    super.key,
    required this.candidate,
    required this.isDark,
    required this.onRevisitTap,
    this.onProfileTap,
    this.isRestoring = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final primaryText = isDark
        ? DarkSanctuaryTokens.primaryText
        : LightSanctuaryTokens.primaryText;
    final subText = isDark
        ? DarkSanctuaryTokens.secondaryText
        : LightSanctuaryTokens.secondaryText;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final border = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    String fullName = 'Sanctuary Member';
    int age = 24;
    String location = 'Saket, Ayodhya';
    String avatarUrl = '';
    bool isVerified = false;
    int resonanceScore = 92;
    String intentQuote = '';

    if (candidate is CandidateProfile) {
      final cand = candidate as CandidateProfile;
      fullName = cand.fullName;
      age = cand.age;
      location = cand.locationName;
      avatarUrl = cand.avatarUrl.isNotEmpty
          ? cand.avatarUrl
          : (cand.photoUrls.isNotEmpty ? cand.photoUrls.first : '');
      isVerified = cand.isVerified;
      resonanceScore = cand.resonanceScore;
      intentQuote = cand.intentQuote;
    } else if (candidate is Map) {
      fullName = candidate['full_name'] as String? ?? 'Sanctuary Member';
      age = candidate['age'] as int? ?? 24;
      location = candidate['location_name'] as String? ?? 'Saket, Ayodhya';
      avatarUrl = candidate['avatar_url'] as String? ?? candidate['avatar'] as String? ?? '';
      isVerified = (candidate['is_kyc_verified'] as bool?) ??
          (candidate['is_verified'] as bool?) ??
          (candidate['kyc_status'] as bool?) ??
          false;
      resonanceScore = candidate['resonance_score'] as int? ?? 92;
      intentQuote = candidate['intent_quote'] as String? ?? candidate['bio'] as String? ?? '';
    }

    final imageProvider = resolveSanctuaryImageProvider(avatarUrl);
    final hasValidAvatar = imageProvider != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onProfileTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: pine.withValues(alpha: 0.15),
                    backgroundImage: imageProvider,
                    child: !hasValidAvatar
                        ? Text(
                            fullName.isNotEmpty ? fullName[0] : 'S',
                            style: TextStyle(
                              color: pine,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$fullName, $age',
                                style: TextStyle(
                                  fontFamily: 'Serif',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 5),
                              Icon(Icons.verified, size: 16, color: pine),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: subText),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(fontSize: 12, color: subText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: pine.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '✨ $resonanceScore% Resonance',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pine,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pine,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: isRestoring
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 15, color: Colors.white),
                    label: Text(
                      isRestoring ? 'Restoring...' : 'Revisit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: isRestoring ? null : onRevisitTap,
                  ),
                ],
              ),
              if (intentQuote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? DarkSanctuaryTokens.inputBackground
                        : LightSanctuaryTokens.chipBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"$intentQuote"',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: subText,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
