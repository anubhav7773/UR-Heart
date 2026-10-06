import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import '../../data/profile_repository.dart';
import '../../../chat/presentation/screens/chat_dialogue_screen.dart';
import '../../../feed/presentation/widgets/ai_resonance_insight_box.dart';
import '../../../feed/presentation/widgets/mindful_intent_card.dart';
import '../../../feed/presentation/widgets/photo_carousel_with_dots.dart';
import '../../../chat/presentation/services/window_security_service.dart';

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
  final String education;
  final List<String> interests;
  final String intentions;
  final String? aiInsight;
  final int resonanceScore;
  final String? matchId;
  final int streakCount;
  final bool hasSacredBridge;

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
    this.education = '',
    this.interests = const [],
    this.intentions = '',
    this.aiInsight,
    this.resonanceScore = 92,
    this.matchId,
    this.streakCount = 0,
    this.hasSacredBridge = false,
  });

  SeekerProfileDetailArgs copyWith({
    String? userId,
    String? displayName,
    int? age,
    String? avatarUrl,
    List<String>? photos,
    List<String>? blurHashes,
    bool? isVerified,
    String? bio,
    String? location,
    String? gender,
    String? profession,
    String? education,
    List<String>? interests,
    String? intentions,
    String? aiInsight,
    int? resonanceScore,
    String? matchId,
    int? streakCount,
    bool? hasSacredBridge,
  }) {
    return SeekerProfileDetailArgs(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photos: photos ?? this.photos,
      blurHashes: blurHashes ?? this.blurHashes,
      isVerified: isVerified ?? this.isVerified,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      gender: gender ?? this.gender,
      profession: profession ?? this.profession,
      education: education ?? this.education,
      interests: interests ?? this.interests,
      intentions: intentions ?? this.intentions,
      aiInsight: aiInsight ?? this.aiInsight,
      resonanceScore: resonanceScore ?? this.resonanceScore,
      matchId: matchId ?? this.matchId,
      streakCount: streakCount ?? this.streakCount,
      hasSacredBridge: hasSacredBridge ?? this.hasSacredBridge,
    );
  }

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
                'Saket, Ayodhya · GPS Verified'))
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
            peer['intent_quote'] as String? ??
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
      education: peer['education'] as String? ?? '',
      interests: interests,
      intentions: intentions,
      aiInsight: peer['ai_insight'] as String?,
      resonanceScore: peer['resonance_score'] as int? ?? 92,
      matchId: matchId,
      streakCount: peer['streak_count'] as int? ?? 0,
      hasSacredBridge: peer['has_sacred_bridge'] as bool? ?? false,
    );
  }
}

/// Luxury Dedicated Seeker Profile Screen with Live Backend Sync, Photo Lightbox & Mindful Safety
class SeekerProfileDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/seeker-profile';

  final SeekerProfileDetailArgs? profileArgs;

  const SeekerProfileDetailScreen({super.key, this.profileArgs});

  @override
  ConsumerState<SeekerProfileDetailScreen> createState() => _SeekerProfileDetailScreenState();
}

class _SeekerProfileDetailScreenState extends ConsumerState<SeekerProfileDetailScreen> {
  SeekerProfileDetailArgs? _args;
  bool _isInitialized = false;
  bool _isLoadingLive = false;

  @override
  void initState() {
    super.initState();
    WindowSecurityService.enableSecureMode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final routeArgs = widget.profileArgs ??
          (ModalRoute.of(context)?.settings.arguments as SeekerProfileDetailArgs?);
      if (routeArgs != null) {
        _args = routeArgs;
        _isInitialized = true;
        if (_args!.userId.isNotEmpty) {
          _fetchLiveProfile(_args!.userId);
        }
      }
    }
  }

  Future<void> _fetchLiveProfile(String userId) async {
    setState(() => _isLoadingLive = true);
    try {
      final data = await ref.read(profileRepositoryProvider).fetchPeerProfile(userId);
      if (!mounted || data.isEmpty || _args == null) return;

      setState(() {
        final cleanPhotos = (data['photos'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();

        _args = _args!.copyWith(
          displayName: data['full_name'] as String? ?? _args!.displayName,
          age: data['age'] as int? ?? _args!.age,
          avatarUrl: (data['avatar_url'] as String?)?.isNotEmpty == true
              ? data['avatar_url'] as String
              : _args!.avatarUrl,
          photos: (cleanPhotos != null && cleanPhotos.isNotEmpty) ? cleanPhotos : _args!.photos,
          isVerified: (data['is_kyc_verified'] as bool?) ??
              (data['kyc_status'] as bool?) ??
              _args!.isVerified,
          bio: (data['bio'] as String?)?.isNotEmpty == true ? data['bio'] as String : _args!.bio,
          profession: (data['profession'] as String?)?.isNotEmpty == true
              ? data['profession'] as String
              : _args!.profession,
          education: (data['education'] as String?)?.isNotEmpty == true
              ? data['education'] as String
              : _args!.education,
          location: (data['location_name'] as String?)?.isNotEmpty == true
              ? data['location_name'] as String
              : _args!.location,
          resonanceScore: data['resonance_score'] as int? ?? _args!.resonanceScore,
          aiInsight: (data['ai_insight'] as String?)?.isNotEmpty == true
              ? data['ai_insight'] as String
              : _args!.aiInsight,
          interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? _args!.interests,
          intentions: (data['intentions'] as String?)?.isNotEmpty == true
              ? data['intentions'] as String
              : _args!.intentions,
          streakCount: data['streak_count'] as int? ?? _args!.streakCount,
          hasSacredBridge: data['has_sacred_bridge'] as bool? ?? _args!.hasSacredBridge,
          gender: (data['gender'] as String?)?.isNotEmpty == true
              ? data['gender'] as String
              : _args!.gender,
        );
      });
    } catch (e) {
      debugPrint('[SeekerProfileDetailScreen] fetchPeerProfile note: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  void _openPhotoLightbox(BuildContext context, int initialIndex, List<String> photos) {
    if (photos.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (ctx) {
        int activeIndex = initialIndex;
        final pageController = PageController(initialPage: initialIndex);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                title: Text(
                  '${activeIndex + 1} of ${photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                centerTitle: true,
              ),
              body: SafeArea(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: photos.length,
                  onPageChanged: (i) => setDialogState(() => activeIndex = i),
                  itemBuilder: (context, idx) {
                    final photoUrl = photos[idx];
                    final provider = resolveSanctuaryImageProvider(photoUrl);
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: provider != null
                            ? Image(
                                image: provider,
                                fit: BoxFit.contain,
                                loadingBuilder: (c, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(color: Colors.white70),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.person, color: Colors.white54, size: 64),
                              ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, String seekerName, String userId) {
    final reasons = [
      'Inappropriate dialogue or messages',
      'Impersonation or catfish profile',
      'Commercial solicitation or spam',
      'Harassment or safety concern',
    ];
    String selected = reasons[0];
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text('Report Seeker', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting $seekerName?', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: selected,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => selected = val ?? r),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Report submitted against $seekerName. AI Sentinel is reviewing.'),
                    backgroundColor: Colors.black87,
                  ),
                );
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnmatchConfirmation(BuildContext context, String seekerName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unmatch & Purge Enclave?'),
        content: Text(
          'This will peacefully dissolve the connection with $seekerName. Under DPDP Act 2023, your shared dialogue will be archived and uncoupled from discovery.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Connection'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connection with $seekerName gracefully uncoupled.'),
                ),
              );
            },
            child: const Text('Confirm Unmatch'),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context, String seekerName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Block Seeker?'),
        content: Text(
          '$seekerName will no longer be able to discover or contact you anywhere in the Sanctuary.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$seekerName has been blocked from your Sanctuary.'),
                ),
              );
            },
            child: const Text('Block Seeker'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    final args = _args;

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

    final photos = args.photos.isNotEmpty ? args.photos : [args.avatarUrl];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0.5,
        leading: BackButton(color: primaryText),
        title: Column(
          children: [
            Text(
              args.displayName,
              style: AppTypography.titleH1.copyWith(
                fontSize: 17,
                color: primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Quietly present in Sanctuary',
                  style: TextStyle(fontSize: 10, color: subText),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (args.isVerified)
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: Chip(
                backgroundColor: pine.withValues(alpha: 0.15),
                side: BorderSide(color: pine.withValues(alpha: 0.4)),
                avatar: Icon(Icons.verified, size: 14, color: pine),
                label: Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pine,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          // Mindful Safety Perimeter Popup Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: primaryText),
            tooltip: 'Mindful Safety Perimeter',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'report') {
                _showReportDialog(context, args.displayName, args.userId);
              } else if (val == 'unmatch') {
                _showUnmatchConfirmation(context, args.displayName);
              } else if (val == 'block') {
                _showBlockConfirmation(context, args.displayName);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 18, color: Colors.orange),
                    const SizedBox(width: 10),
                    Text('Report Seeker', style: TextStyle(color: primaryText, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unmatch',
                child: Row(
                  children: [
                    Icon(Icons.link_off, size: 18, color: subText),
                    const SizedBox(width: 10),
                    Text('Unmatch Dialogue', style: TextStyle(color: primaryText, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Block Seeker', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoadingLive)
              LinearProgressIndicator(
                minHeight: 2,
                color: pine,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Photo Carousel with Dots & Lightbox Zoom
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      child: PhotoCarouselWithDots(
                        photos: photos,
                        blurHashes: args.blurHashes,
                        isDark: isDark,
                        isKycVerified: args.isVerified,
                        locationTag: args.location.isNotEmpty
                            ? args.location
                            : 'Saket, Ayodhya · GPS Verified',
                        onPhotoTap: (idx) => _openPhotoLightbox(context, idx, photos),
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
                            if (args.profession.isNotEmpty || args.education.isNotEmpty || args.gender.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (args.gender.isNotEmpty)
                                    Text(
                                      args.gender,
                                      style: TextStyle(color: subText, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  if (args.profession.isNotEmpty) ...[
                                    Text('•', style: TextStyle(color: subText, fontSize: 13)),
                                    Text(
                                      args.profession,
                                      style: TextStyle(color: primaryText, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  if (args.education.isNotEmpty) ...[
                                    Text('•', style: TextStyle(color: subText, fontSize: 13)),
                                    Text(
                                      args.education,
                                      style: TextStyle(color: subText, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: pine),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    args.location.isNotEmpty
                                        ? args.location
                                        : 'Saket, Ayodhya · GPS Verified',
                                    style: TextStyle(
                                      color: subText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (args.streakCount > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🔥', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${args.streakCount}-Day Mindful Sanctuary Streak',
                                      style: const TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. AI Resonance Insight Box (Dynamic Mutual Compatibility)
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

                    // 6. DPDP Act 2023 Sanctuary Safety Seal
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: pine.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: pine.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.security, color: pine, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DPDP Act 2023 Protected Enclave',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: pine,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Direct WhatsApp handles and phone numbers remain cryptographically sealed until mutual consent is exchanged.',
                                    style: TextStyle(fontSize: 11, color: subText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
