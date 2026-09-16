import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/features/auth/presentation/onboarding_screen.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';

/// Screen 6: Profile, Streak Vault & One-Tap Account Erase Center
/// Spec: URH-UIX-009 Section 3 Screen 6
class ProfileVaultScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onOneTapErase;

  const ProfileVaultScreen({
    super.key,
    this.lang = 'en',
    this.onOneTapErase,
  });

  @override
  State<ProfileVaultScreen> createState() => _ProfileVaultScreenState();
}

class _ProfileVaultScreenState extends State<ProfileVaultScreen> {
  final ProfileRepository _profileRepo = ProfileRepository();
  UserProfileData? _profile;
  bool _isLoading = true;
  bool _isErasing = false;

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: URHeartColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: URHeartColors.statusDanger, size: 28),
            const SizedBox(width: 8),
            Text(
              _t('dataEraseButton'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          _t('dataEraseNotice'),
          style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: URHeartColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: URHeartColors.statusDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Erase All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: URHeartColors.statusSuccess,
            content: Text('Account and all photos permanently erased.'),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isErasing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: URHeartColors.statusDanger,
            content: Text('Account erase failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _profile?.fullName ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Aman Gupta';
    final userCity = _profile?.city ?? 'Lucknow, UP';
    final streak = _profile?.streakCount ?? 14;
    final rewardTokens = _profile?.rewardBalance ?? 9;

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
                                child: const Center(
                                  child: Icon(Icons.person, size: 50, color: URHeartColors.textSecondary),
                                ),
                              ),
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded, color: URHeartColors.accentGold, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Level 2: Silver Spark 🔥',
                                  style: TextStyle(
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
                                      const Text(
                                        '42 Views',
                                        style: TextStyle(
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
                    const SizedBox(height: 20),

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
                            onTap: () {},
                          ),
                          const Divider(height: 1, color: URHeartColors.surfaceRaised),
                          _buildSettingsTile(
                            icon: Icons.gavel_rounded,
                            title: 'Grievance Redressal & Legal (ASI Verticals)',
                            onTap: () {},
                          ),
                          const Divider(height: 1, color: URHeartColors.surfaceRaised),
                          _buildSettingsTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy & Blocked Users',
                            onTap: () {},
                          ),
                        ],
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

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: URHeartColors.textSecondary, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 13.5),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: URHeartColors.textMuted, size: 20),
      onTap: onTap,
    );
  }
}
