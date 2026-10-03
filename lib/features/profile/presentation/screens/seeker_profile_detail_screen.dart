import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../chat/presentation/screens/chat_dialogue_screen.dart';
import '../../../feed/presentation/widgets/ai_resonance_insight_box.dart';
import '../../../feed/presentation/widgets/mindful_intent_card.dart';
import '../../../feed/presentation/widgets/photo_carousel_with_dots.dart';

/// Arguments payload for [SeekerProfileDetailScreen]
class SeekerProfileDetailArgs {
  final String userId;
  final String displayName;
  final int? age;
  final String avatarUrl;
  final List<String> photos;
  final List<String> blurHashes;
  final bool isVerified;
  final String bio;
  final String location;
  final String gender;
  final String profession;
  final List<String> interests;
  final String intentions;
  final String? aiInsight;
  final int resonanceScore;
  final String? matchId;

  const SeekerProfileDetailArgs({
    required this.userId,
    required this.displayName,
    this.age,
    required this.avatarUrl,
    this.photos = const [],
    this.blurHashes = const [],
    this.isVerified = false,
    this.bio = '',
    this.location = '',
    this.gender = '',
    this.profession = '',
    this.interests = const [],
    this.intentions = '',
    this.aiInsight,
    this.resonanceScore = 92,
    this.matchId,
  });

  factory SeekerProfileDetailArgs.fromPeer({
    required Map<String, dynamic> peer,
    ChatDialogueArguments? args,
    String? matchId,
  }) {
    final avatar = (args?.recipientAvatarUrl.isNotEmpty == true
            ? args!.recipientAvatarUrl
            : (peer['avatar_url'] as String? ??
                peer['recipient_avatar_url'] as String? ??
                peer['partner_photo'] as String? ??
                peer['peer_photo'] as String? ??
                peer['avatar'] as String? ??
                ''))
        .trim();

    final rawPhotos = (peer['photos'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        (peer['photo_urls'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final allPhotos = <String>[];
    if (avatar.isNotEmpty) allPhotos.add(avatar);
    for (final p in rawPhotos) {
      if (!allPhotos.contains(p)) allPhotos.add(p);
    }

    final name = args != null && args.recipientName.isNotEmpty
        ? args.recipientName
        : (peer['full_name'] as String? ??
            peer['name'] as String? ??
            'Sanctuary Seeker');

    final age = args?.recipientAge ?? (peer['age'] as int?);

    final bio = (args?.bio.isNotEmpty == true
            ? args!.bio
            : (peer['bio'] as String? ?? ''))
        .trim();

    final location = (args?.location.isNotEmpty == true
            ? args!.location
            : (peer['location'] as String? ??
                peer['city'] as String? ??
                peer['location_name'] as String? ??
                'Ayodhya, Uttar Pradesh · GPS Verified'))
        .trim();

    final isVerified = args?.isVerified ??
        (peer['is_verified'] as bool? ??
            peer['is_kyc_verified'] as bool? ??
            peer['kyc_status'] as bool? ??
            false);

    final interests = (args?.interests.isNotEmpty == true
        ? args!.interests
        : ((peer['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[]));

    final intentions = (peer['intentions'] as String? ??
            'Appreciating intentional conversations and authentic connection.')
        .trim();

    return SeekerProfileDetailArgs(
      userId: peer['id']?.toString() ?? peer['recipient_id']?.toString() ?? '',
      displayName: name,
      age: age,
      avatarUrl: avatar,
      photos: allPhotos.isNotEmpty ? allPhotos : (avatar.isNotEmpty ? [avatar] : []),
      blurHashes: (peer['blur_hashes'] as List<dynamic>?)?.cast<String>() ?? const [],
      isVerified: isVerified,
      bio: bio,
      location: location,
      gender: peer['gender'] as String? ?? '',
      profession: peer['profession'] as String? ?? peer['looking_for'] as String? ?? '',
      interests: interests,
      intentions: intentions,
      aiInsight: peer['ai_insight'] as String?,
      resonanceScore: peer['resonance_score'] as int? ?? 92,
      matchId: matchId,
    );
  }
}

/// Luxury Full-Screen Seeker Profile Screen
/// Opened from Chat Dialogue or Sanctuary Matches to view complete profile & photo carousel.
class SeekerProfileDetailScreen extends ConsumerWidget {
  static const String routeName = '/seeker-profile';

  final SeekerProfileDetailArgs? profileArgs;

  const SeekerProfileDetailScreen({super.key, this.profileArgs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    final bg = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final surface = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final primaryText = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final subText = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;

    final args = profileArgs ??
        (ModalRoute.of(context)?.settings.arguments as SeekerProfileDetailArgs?);

    if (args == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: primaryText),
        ),
        body: Center(
          child: Text(
            'Seeker profile not found.',
            style: TextStyle(color: subText, fontSize: 16),
          ),
        ),
      );
    }

    final displayNameWithAge = args.age != null
        ? '${args.displayName}, ${args.age}'
        : args.displayName;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0.5,
        leading: BackButton(color: primaryText),
        title: Text(
          args.displayName,
          style: AppTypography.titleH1.copyWith(
            fontSize: 18,
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: args.isVerified
                  ? pine.withValues(alpha: 0.15)
                  : subText.withValues(alpha: 0.1),
              side: BorderSide(
                color: args.isVerified
                    ? pine.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
              avatar: Icon(
                args.isVerified ? Icons.verified : Icons.shield_outlined,
                size: 15,
                color: args.isVerified ? pine : subText,
              ),
              label: Text(
                args.isVerified ? 'Verified' : 'Seeker',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: args.isVerified ? pine : subText,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Photo Carousel with Dots
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      child: PhotoCarouselWithDots(
                        photos: args.photos.isNotEmpty
                            ? args.photos
                            : [args.avatarUrl],
                        blurHashes: args.blurHashes,
                        isDark: isDark,
                        isKycVerified: args.isVerified,
                        locationTag: args.location.isNotEmpty
                            ? args.location
                            : 'Ayodhya, Uttar Pradesh',
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Main Profile Info Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? DarkSanctuaryTokens.surfaceCardBorder
                                : LightSanctuaryTokens.surfaceCardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    displayNameWithAge,
                                    style: TextStyle(
                                      fontFamily: 'Serif',
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryText,
                                    ),
                                  ),
                                ),
                                if (args.isVerified) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.verified, size: 22, color: pine),
                                ],
                              ],
                            ),
                            if (args.profession.isNotEmpty || args.gender.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (args.gender.isNotEmpty) args.gender,
                                  if (args.profession.isNotEmpty) args.profession,
                                ].join(' • '),
                                style: TextStyle(
                                  color: subText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 15, color: pine),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    args.location.isNotEmpty
                                        ? args.location
                                        : 'Ayodhya, Uttar Pradesh · GPS Verified',
                                    style: TextStyle(
                                      color: subText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. AI Resonance Insight Box
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AiResonanceInsightBox(
                        isDark: isDark,
                        insightText: args.aiInsight != null && args.aiInsight!.isNotEmpty
                            ? args.aiInsight!
                            : 'A shared affinity for soulful reflection and intentional sanctuary connection illuminates your resonance.',
                        resonanceScore: args.resonanceScore,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. Sacred Intent & Core Passions Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: MindfulIntentCard(
                        isDark: isDark,
                        bio: args.bio.isNotEmpty
                            ? args.bio
                            : 'Mindful presence seeking deep, authentic dialogue in the Sanctuary.',
                        interestTags: args.interests,
                      ),
                    ),

                    // 5. Resonance Intentions
                    if (args.intentions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? DarkSanctuaryTokens.surfaceCardBorder
                                  : LightSanctuaryTokens.surfaceCardBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 16, color: pine),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Resonance Intentions',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: pine,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                args.intentions,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: primaryText,
                                  height: 1.45,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? DarkSanctuaryTokens.surfaceCardBorder
                        : LightSanctuaryTokens.surfaceCardBorder,
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: const Text(
                      'Back to Dialogue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pine,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
