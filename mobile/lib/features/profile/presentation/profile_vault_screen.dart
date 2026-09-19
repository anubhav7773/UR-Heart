import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/features/auth/presentation/onboarding_screen.dart';
import 'manage_photos_screen.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';
import '../../admin/presentation/admin_kyc_dashboard.dart';
import '../../ads/services/consent_manager.dart';
import '../../legal/presentation/grievance_hub_screen.dart';
import '../../privacy/presentation/privacy_center_screen.dart';
import '../../wallet/presentation/manual_rewards_hub_screen.dart';

/// Screen 6: Profile, Streak Vault & One-Tap Account Erase Center
/// Spec: URH-UIX-009 Section 3 Screen 6
class ProfileVaultScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onOneTapErase;
  final ProfileRepository? repository;
  final UserProfileData? initialProfile;

  const ProfileVaultScreen({
    super.key,
    this.lang = 'en',
    this.onOneTapErase,
    this.repository,
    this.initialProfile,
  });

  @override
  State<ProfileVaultScreen> createState() => _ProfileVaultScreenState();
}

class _ProfileVaultScreenState extends State<ProfileVaultScreen> {
  late final ProfileRepository _profileRepo = widget.repository ?? ProfileRepository();
  UserProfileData? _profile;
  late bool _isLoading = widget.initialProfile == null;
  bool _isErasing = false;

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final data = await _profileRepo.getProfile();
    if (mounted) {
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndEraseAccount() async {
    final confirmController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: URHeartColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: URHeartColors.statusDanger, size: 24),
            SizedBox(width: 8),
            Text(
              'Erase All Data?',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Under Section 11 of DPDP Act 2023, this action is permanent and irreversible:\n\n'
              '• All 5 profile photos will be wiped from cloud storage.\n'
              '• All chats, matches, and streaks will be destroyed.\n'
              '• Your account credentials will be permanently erased.',
              style: TextStyle(color: URHeartColors.textPrimary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              "Type 'DELETE' to confirm:",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: const TextStyle(color: URHeartColors.textMuted),
                filled: true,
                fillColor: const Color(0xFF22222C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: URHeartColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: URHeartColors.statusDanger),
            onPressed: () {
              if (confirmController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Please type 'DELETE' exactly to confirm.")),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text(
              'Permanently Erase',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isErasing = true;
    });

    try {
      await _profileRepo.eraseAccount();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: URHeartColors.statusSuccess,
          content: Text('Account and all data permanently erased per DPDP Act 2023 Section 11.'),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isErasing = false;
      });
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: URHeartColors.statusDanger,
          content: Text('Account erase failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String? fallbackName;
    try {
      fallbackName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {}

    final userName = (_profile?.fullName.isNotEmpty == true)
        ? _profile!.fullName
        : (fallbackName?.isNotEmpty == true
            ? fallbackName!
            : 'UR-Heart User');
    final userCity = (_profile?.city.isNotEmpty == true) ? _profile!.city : 'City Not Set';
    final streak = _profile?.streakCount ?? 0;
    final rewardTokens = _profile?.rewardBalance ?? 0;
    final int adsSupported = (rewardTokens * 3);

    String tierText;
    if (streak >= 14) {
      tierText = 'Level 3: Gold Flame 🔥';
    } else if (streak >= 7) {
      tierText = 'Level 2: Silver Spark ✨';
    } else if (streak >= 1) {
      tierText = 'Level 1: Bronze Spark ⚡';
    } else {
      tierText = 'New Spark 🌱';
    }

    String currentEmail = '';
    try {
      currentEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    } catch (_) {}
    final bool isMasterAdmin = currentEmail == "kshtriyaanubhav9120@gmail.com";

    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
        title: const Text('Profile & Security Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: URHeartColors.brandPrimary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Section
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: URHeartColors.accentGold, width: 2.5),
                                  color: URHeartColors.surfaceRaised,
                                ),
                                child: ClipOval(
                                  child: (_profile != null &&
                                          _profile!.photos.isNotEmpty &&
                                          _profile!.photos.first.photoUrl.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: _profile!.photos.first.photoUrl,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          placeholder: (ctx, url) => (_profile!.photos.first.blurHash.isNotEmpty)
                                              ? BlurHash(hash: _profile!.photos.first.blurHash)
                                              : Container(color: URHeartColors.surfaceRaised),
                                          errorWidget: (ctx, url, err) => const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(Icons.person, size: 50, color: URHeartColors.textSecondary),
                                        ),
                                ),
                              ),
                              if (_profile?.kycStatus == true)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: URHeartColors.brandSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.black, size: 14),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userName,
                            style: const TextStyle(
                              color: URHeartColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userCity,
                            style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 8),

                          // Tier Badge Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: URHeartColors.accentGold.withValues(alpha: 0.15),
                              borderRadius: URHeartTheme.radiusPill,
                              border: Border.all(color: URHeartColors.accentGold),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: URHeartColors.accentGold, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  tierText,
                                  style: const TextStyle(
                                    color: URHeartColors.accentGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Streak & Reward Vault
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: URHeartColors.cardSurface,
                        borderRadius: URHeartTheme.radiusCard,
                        border: Border.all(color: URHeartColors.surfaceRaised),
                      ),
                      child: Column(
                        children: [
                          // Big Flame Streak Heading
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.whatshot_rounded, color: URHeartColors.accentGold, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                '$streak Days Active Streak',
                                style: const TextStyle(
                                  color: URHeartColors.accentGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Stat Grid (2 columns)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: URHeartColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _t('directDmsBalance'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '🪙 $rewardTokens Credits',
                                        style: const TextStyle(
                                          color: URHeartColors.brandSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: URHeartColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _t('totalAdsSupported'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$adsSupported Views',
                                        style: const TextStyle(
                                          color: URHeartColors.statusSuccess,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Persistence Warning Notice
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: URHeartColors.accentGold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: URHeartColors.accentGold.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _t('uninstallWarning'),
                              style: const TextStyle(
                                color: URHeartColors.accentGold,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Watch Ads & Earn Rewards Hub Tile
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161D),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.35)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD166).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.card_giftcard, color: Color(0xFFFFD166), size: 22),
                          ),
                          title: const Text(
                            "Watch Ads & Earn Rewards / रिवॉर्ड पाएं",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            "Claim Direct DMs, WhatsApp Tokens & Shields (10s, 20s, 30s)",
                            style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFD166)),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ManualRewardsHubScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Render Super Admin banner if master admin
                    if (isMasterAdmin) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16161D),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.5)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.shield_rounded, color: Color(0xFFFFD166)),
                          title: const Text(
                            "Super Admin KYC Hub",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            "Manual override portal & pending queue",
                            style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD166), size: 14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminKycDashboardScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Account & Safety Settings List
                    Container(
                      decoration: BoxDecoration(
                        color: URHeartColors.cardSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: URHeartColors.surfaceRaised),
                      ),
                      child: Column(
                        children: [
                          _buildSettingsTile(
                            icon: Icons.edit_rounded,
                            title: 'Edit Profile & 5 Photos',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ManagePhotosScreen()),
                              ).then((_) => _loadProfile());
                            },
                          ),
                          _buildFivePhotoPreviewGrid(),
                          const Divider(height: 1, color: URHeartColors.surfaceRaised),
                          _buildSettingsTile(
                            icon: Icons.gavel_rounded,
                            title: 'Grievance Redressal & Legal (ASI Verticals)',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GrievanceHubScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1, color: URHeartColors.surfaceRaised),
                          _buildSettingsTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy & Blocked Users',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PrivacyCenterScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF08D9D6), size: 20),
                        title: const Text(
                          "Ad Privacy & Tracking Preferences",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          "Manage Google UMP consent for personalized ads",
                          style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 13),
                        onTap: () {
                          ConsentManager.instance.showPrivacyOptionsForm(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Danger Zone: One-Tap Account Erase Center
                    SizedBox(
                      height: URHeartTheme.minTouchTarget,
                      child: OutlinedButton(
                        onPressed: _isErasing ? null : _confirmAndEraseAccount,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: URHeartColors.statusDanger, width: 1.5),
                        ),
                        child: _isErasing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: URHeartColors.statusDanger, strokeWidth: 2),
                              )
                            : Text(
                                _t('dataEraseButton'),
                                style: const TextStyle(
                                  color: URHeartColors.statusDanger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('dataEraseNotice'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: URHeartColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFivePhotoPreviewGrid() {
    final photos = _profile?.photos ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Photos & KYC Slots (${photos.length}/5)',
                style: const TextStyle(
                  color: URHeartColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManagePhotosScreen()),
                  ).then((_) => _loadProfile());
                },
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    color: URHeartColors.brandSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final slotIndex = index + 1;
              UserProfilePhoto? photo;
              for (final p in photos) {
                if (p.slotIndex == slotIndex) {
                  photo = p;
                  break;
                }
              }

              final slotPhoto = photo;
              final bool hasPhoto = slotPhoto != null && slotPhoto.photoUrl.isNotEmpty;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 4 ? 0 : 8.0),
                  child: AspectRatio(
                    aspectRatio: 0.8,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ManagePhotosScreen()),
                        ).then((_) => _loadProfile());
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: URHeartColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasPhoto
                                ? URHeartColors.brandPrimary.withValues(alpha: 0.8)
                                : URHeartColors.surfaceRaised,
                            width: hasPhoto ? 1.5 : 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasPhoto)
                              CachedNetworkImage(
                                imageUrl: slotPhoto.photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => slotPhoto.blurHash.isNotEmpty
                                    ? BlurHash(hash: slotPhoto.blurHash)
                                    : Container(color: URHeartColors.surfaceRaised),
                                errorWidget: (ctx, url, err) => const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              )
                            else
                              const Center(
                                child: Icon(
                                  Icons.add_rounded,
                                  color: URHeartColors.textMuted,
                                  size: 20,
                                ),
                              ),
                            Positioned(
                              bottom: 2,
                              left: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  slotIndex == 1 ? 'Hero' : '#$slotIndex',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: URHeartColors.textSecondary, size: 22),
        title: Text(
          title,
          style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 13.5),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: URHeartColors.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}
