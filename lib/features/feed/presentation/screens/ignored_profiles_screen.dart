import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../profile/presentation/screens/seeker_profile_detail_screen.dart';
import '../../domain/candidate_profile.dart';
import '../widgets/ignored_profile_tile.dart';
import '../controllers/ignored_profiles_controller.dart';

class IgnoredProfilesScreen extends ConsumerWidget {
  const IgnoredProfilesScreen({super.key});

  static const String routeName = '/ignored';

  void _openCandidateProfile(BuildContext context, dynamic candidate) {
    String id = '';
    String name = 'Sanctuary Seeker';
    int age = 24;
    String avatar = '';
    List<String> photos = <String>[];
    bool isVerified = false;
    String location = 'Saket, Ayodhya · GPS Verified';
    int resonance = 92;
    String bio = '';
    String intentQuote = '';
    List<String> interests = <String>[];

    if (candidate is CandidateProfile) {
      id = candidate.id;
      name = candidate.fullName;
      age = candidate.age;
      avatar = candidate.avatarUrl.isNotEmpty
          ? candidate.avatarUrl
          : (candidate.photoUrls.isNotEmpty ? candidate.photoUrls.first : '');
      photos = candidate.photoUrls;
      isVerified = candidate.isVerified;
      location = candidate.locationName;
      resonance = candidate.resonanceScore;
      bio = candidate.intentQuote;
      intentQuote = candidate.intentQuote;
      interests = candidate.interests;
    } else if (candidate is Map) {
      id = candidate['id'] as String? ?? '';
      name = candidate['full_name'] as String? ?? 'Sanctuary Seeker';
      age = candidate['age'] as int? ?? 24;
      avatar = candidate['avatar_url'] as String? ?? candidate['avatar'] as String? ?? '';
      final rawPhotos = (candidate['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (candidate['photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (avatar.isNotEmpty ? <String>[avatar] : <String>[]);
      photos = rawPhotos;
      isVerified = (candidate['is_kyc_verified'] as bool?) ??
          (candidate['is_verified'] as bool?) ??
          (candidate['kyc_status'] as bool?) ??
          false;
      location = candidate['location_name'] as String? ?? 'Saket, Ayodhya · GPS Verified';
      resonance = candidate['resonance_score'] as int? ?? 92;
      bio = candidate['bio'] as String? ?? candidate['intent_quote'] as String? ?? '';
      intentQuote = candidate['intent_quote'] as String? ?? '';
      interests = (candidate['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          <String>[];
    }

    Navigator.of(context).pushNamed(
      SeekerProfileDetailScreen.routeName,
      arguments: SeekerProfileDetailArgs(
        userId: id,
        displayName: name,
        age: age,
        avatarUrl: avatar,
        photos: photos.isNotEmpty ? photos : (avatar.isNotEmpty ? <String>[avatar] : <String>[]),
        isVerified: isVerified,
        bio: bio,
        location: location,
        resonanceScore: resonance,
        intentions: intentQuote,
        interests: interests,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final vaultState = ref.watch(ignoredProfilesControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: primaryText),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pass Vault',
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
                letterSpacing: 0.5,
              ),
            ),
            if (vaultState.passedProfiles.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: pine.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${vaultState.passedProfiles.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pine,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryText),
            tooltip: 'Refresh Vault',
            onPressed: () => ref.read(ignoredProfilesControllerProvider.notifier).loadPassedProfiles(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: pine,
          backgroundColor: isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard,
          onRefresh: () => ref.read(ignoredProfilesControllerProvider.notifier).loadPassedProfiles(),
          child: vaultState.isLoading && vaultState.passedProfiles.isEmpty
              ? Center(child: CircularProgressIndicator(color: pine))
              : vaultState.passedProfiles.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: pine.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.history_edu, size: 40, color: pine),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your Pass Vault is Quiet',
                                style: TextStyle(
                                  fontFamily: 'Serif',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 36),
                                child: Text(
                                  'Seekers you pass during discovery are preserved in your private enclave. You can revisit them here at any time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: subText, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: pine),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tap any seeker to review full profile before revisiting.',
                                  style: TextStyle(fontSize: 12, color: subText),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: vaultState.passedProfiles.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final candidate = vaultState.passedProfiles[index];
                              final String id = candidate is CandidateProfile
                                  ? candidate.id
                                  : (candidate is Map ? (candidate['id'] as String? ?? '') : '');
                              final String name = candidate is CandidateProfile
                                  ? candidate.fullName
                                  : (candidate is Map ? (candidate['full_name'] as String? ?? 'Sanctuary Member') : 'Sanctuary Member');

                              final isRestoringThis = vaultState.restoringId == id;

                              return IgnoredProfileTile(
                                candidate: candidate,
                                isDark: isDark,
                                isRestoring: isRestoringThis,
                                onProfileTap: () => _openCandidateProfile(context, candidate),
                                onRevisitTap: () async {
                                  await ref
                                      .read(ignoredProfilesControllerProvider.notifier)
                                      .revisitProfile(id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$name restored to discovery deck.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Text(
                            'Passed profiles are preserved in your encrypted local enclave under DPDP Act 2023. Revisit at any time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: subText.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
