import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../settings/blocked_users_screen.dart';
import '../../screens/admin_verification_screen.dart';
import '../../core/utils/feedback_helper.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/image_guard_service.dart';
import 'edit_profile_screen.dart';
import 'manage_subscriptions_sheet.dart';
import 'profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _activePasses;
  bool _isBoosted = false;
  String? _boostBadgeText;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await _profileService.getUserProfile();
      try {
        final passRes = await ApiClient.instance.getActivePassStatus();
        if (passRes.data != null && passRes.data['data'] != null) {
          final passData = passRes.data['data'];
          _activePasses = Map<String, dynamic>.from(passData);
          _isBoosted = passData['is_boosted'] ?? false;
          _boostBadgeText = passData['boost_badge_text'];
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profileData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice loading profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface_card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border_subtle),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.accent_primary),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from UR Heart?',
          style: TextStyle(color: AppTheme.text_secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.text_secondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent_primary),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      await AppAuthProvider.instance.logout();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    bool isDeleting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface_card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x33FF4D67), width: 1),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.status_destructive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppTheme.status_destructive,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delete Account Permanently?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'All your profile details, matches, photos, and messages will be permanently removed. This action cannot be undone.',
                style: TextStyle(
                  color: AppTheme.text_secondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                OutlinedButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border_subtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            final res = await ApiClient.instance.deleteAccount();
                            if (res.statusCode == 200) {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              // 1. Clear local cache & tokens
                              await AppAuthProvider.instance.purgeSession();

                              // 2. Sign out of Firebase Auth
                              try {
                                await FirebaseAuth.instance.signOut();
                              } catch (_) {}

                              if (!context.mounted) return;

                              // 3. Navigate back to Auth screen
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const AuthScreen()),
                                (route) => false,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Your account has been permanently deleted.'),
                                  backgroundColor: AppTheme.status_destructive,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            } else {
                              setDialogState(() => isDeleting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.data?['message'] ?? 'Failed to delete account. Please try again.'),
                                    backgroundColor: AppTheme.status_destructive,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Network error during account deletion. Please try again.'),
                                  backgroundColor: AppTheme.status_destructive,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.status_destructive,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProfileSheet() {
    if (_profileData == null) return;

    final String initialName = _profileData!['full_name'] ?? '';
    final String initialBio = _profileData!['bio'] ?? '';
    final String initialArea = _profileData!['area_name'] ?? '';
    final String initialPin = _profileData!['village_pin_code'] ?? '';
    String currentIntent = _profileData!['intent'] ?? 'casual';

    final nameController = TextEditingController(text: initialName);
    final bioController = TextEditingController(text: initialBio);
    final areaController = TextEditingController(text: initialArea);
    final pinController = TextEditingController(text: initialPin);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface_card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.text_secondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(color: AppTheme.text_secondary),
                        filled: true,
                        fillColor: AppTheme.surface_interactive,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: const TextStyle(color: AppTheme.text_secondary),
                        filled: true,
                        fillColor: AppTheme.surface_interactive,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: areaController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Area / Landmark',
                              labelStyle: const TextStyle(color: AppTheme.text_secondary),
                              filled: true,
                              fillColor: AppTheme.surface_interactive,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'PIN Code',
                              labelStyle: const TextStyle(color: AppTheme.text_secondary),
                              filled: true,
                              fillColor: AppTheme.surface_interactive,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Intent Goal',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Casual Conversations'),
                          selected: currentIntent == 'casual',
                          selectedColor: AppTheme.accent_primary,
                          onSelected: (sel) => setModalState(() => currentIntent = 'casual'),
                        ),
                        ChoiceChip(
                          label: const Text('Serious Marriage'),
                          selected: currentIntent == 'serious',
                          selectedColor: AppTheme.accent_primary,
                          onSelected: (sel) => setModalState(() => currentIntent = 'serious'),
                        ),
                        ChoiceChip(
                          label: const Text('Friendship'),
                          selected: currentIntent == 'friendship',
                          selectedColor: AppTheme.accent_primary,
                          onSelected: (sel) => setModalState(() => currentIntent = 'friendship'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                final payload = {
                                  'full_name': nameController.text.trim(),
                                  'bio': bioController.text.trim(),
                                  'area_name': areaController.text.trim(),
                                  'village_pin_code': pinController.text.trim(),
                                  'intent': currentIntent,
                                };
                                await _profileService.updateProfile(payload);
                                if (context.mounted) Navigator.pop(context);
                                _fetchProfile();
                              } catch (e) {
                                setModalState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent_primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getCacheBusterUrl(String url) {
    if (url.isEmpty) return '';
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String separator = url.contains('?') ? '&' : '?';
    return '$url${separator}t=$timestamp';
  }

  Future<void> _uploadNewPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (pickedFile != null) {
        // On-Device OCR Text Guard Check
        final isClean = await ImageGuardService.validateProfilePhoto(pickedFile.path);
        if (!isClean) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.status_destructive,
                content: Text(
                  "⚠️ Photo me phone number, Insta ID, ya text likhna mana hai. Kripya apni real photo upload karein.",
                ),
              ),
            );
          }
          return;
        }

        setState(() => _isLoading = true);
        final File imageFile = File(pickedFile.path);
        final String? uploadedUrl = await _profileService.uploadProfilePhoto(imageFile);

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();

          if (mounted) {
            setState(() {
              final List<dynamic> currentPhotos = List.from(_profileData?['photos'] ?? []);
              if (!currentPhotos.contains(uploadedUrl)) {
                currentPhotos.insert(0, uploadedUrl);
              }
              if (_profileData != null) {
                _profileData!['photos'] = currentPhotos;
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload notice: ${e.toString()}')),
        );
      }
    } finally {
      _fetchProfile();
    }
  }

  Future<void> _startVideoVerification() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 10),
        preferredCameraDevice: CameraDevice.front,
      );

      if (video != null) {
        setState(() => _isLoading = true);
        final File videoFile = File(video.path);
        final res = await _profileService.uploadVerificationVideo(videoFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res?['message'] ?? 'Selfie video uploaded! Verification status is now PENDING review.'),
              backgroundColor: AppTheme.status_online,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video verification notice: ${e.toString()}'),
            backgroundColor: AppTheme.accent_boost_gold,
          ),
        );
      }
    } finally {
      _fetchProfile();
    }
  }

  Widget _buildVerificationCard(bool isVerified, String verificationStatus) {
    if (isVerified || verificationStatus == 'APPROVED') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface_card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent_verified_blue.withValues(alpha: 0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.accent_verified_blue, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Verified',
                    style: TextStyle(fontSize: 14, color: AppTheme.accent_verified_blue, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your identity & selfie video are approved with the Blue Badge.',
                    style: TextStyle(fontSize: 12, color: AppTheme.text_secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (verificationStatus == 'PENDING') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface_card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent_boost_gold.withValues(alpha: 0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: AppTheme.accent_boost_gold, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Under Review',
                    style: TextStyle(fontSize: 14, color: AppTheme.accent_boost_gold, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your selfie video has been submitted. Moderation review takes up to 24h.',
                    style: TextStyle(fontSize: 12, color: AppTheme.text_secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (verificationStatus == 'REJECTED') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface_card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.status_destructive.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppTheme.status_destructive, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Rejected',
                        style: TextStyle(fontSize: 14, color: AppTheme.status_destructive, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your selfie video did not pass clarity guidelines. Please record again.',
                        style: TextStyle(fontSize: 12, color: AppTheme.text_secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startVideoVerification,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Record Selfie Video Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent_primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // UNVERIFIED
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface_card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border_subtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent_verified_blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: AppTheme.accent_verified_blue, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Get Verified & Stand Out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Record a quick 5-second selfie video to earn the blue checkmark badge & get 3x more matches.',
              style: TextStyle(fontSize: 12, color: AppTheme.text_secondary),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startVideoVerification,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Verify Now (5-Sec Selfie)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent_primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? AppTheme.text_primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.text_secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.text_tertiary,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.surface_root,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent_primary)),
      );
    }

    final photos = (_profileData?['photos'] as List<dynamic>?) ?? [];
    final String mainPhoto = photos.isNotEmpty ? photos.first as String : '';
    final String fullName = _profileData?['full_name'] ?? 'RuralHeart User';
    final int? age = _profileData?['age'];
    final String bio = _profileData?['bio'] ?? 'No bio added yet.';
    final String gender = (_profileData?['gender'] ?? 'male').toString().toUpperCase();
    final String areaName = _profileData?['area_name'] ?? 'Ayodhya';
    final String intent = _profileData?['intent'] ?? 'casual';
    final bool isVerified = _profileData?['is_verified'] == true;
    final String verificationStatus = (_profileData?['verification_status'] ?? 'UNVERIFIED').toString().toUpperCase();

    return Scaffold(
      backgroundColor: AppTheme.surface_root,
      appBar: AppBar(
        backgroundColor: AppTheme.surface_root,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.status_destructive),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Header & Avatar Unit (96dp avatar in 3dp gradient ring)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.accent_primary, AppTheme.accent_boost_gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface_card,
                    ),
                    child: ClipOval(
                      child: mainPhoto.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _getCacheBusterUrl(mainPhoto),
                              key: UniqueKey(),
                              fit: BoxFit.cover,
                              width: 96,
                              height: 96,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              placeholder: (context, url) => Container(
                                color: AppTheme.surface_card,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppTheme.accent_primary, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, error, stackTrace) =>
                                  const Icon(Icons.person, size: 50, color: AppTheme.text_tertiary),
                            )
                          : const Icon(Icons.person, size: 50, color: AppTheme.text_tertiary),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _uploadNewPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent_primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // User Name & Location / Verified Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  age != null && age > 0 ? '$fullName, $age' : fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: AppTheme.accent_verified_blue, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Active Presence & Area Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.status_online,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Active Now',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.status_online,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  $areaName',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.text_secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Active Boost Badge
            if (_isBoosted && _boostBadgeText != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.deepOrangeAccent, blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _boostBadgeText!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Feature Banner 1: Monetization & VIP Passes Hub
            _buildManagePassesTile(context, _activePasses),
            const SizedBox(height: 12),

            // Feature Banner 2: Video Verification Status Card
            _buildVerificationCard(isVerified, verificationStatus),
            const SizedBox(height: 16),

            // Structured Photos Gallery Grid (3-Column Square Tiles)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface_card,
                borderRadius: BorderRadius.circular(AppTheme.radius_md),
                border: Border.all(color: AppTheme.border_subtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Photos (${photos.length}/6)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (photos.length < 6)
                        GestureDetector(
                          onTap: _uploadNewPhoto,
                          child: const Row(
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: AppTheme.accent_primary, size: 16),
                              SizedBox(width: 4),
                              Text('Add', style: TextStyle(color: AppTheme.accent_primary, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: (photos.length < 6) ? photos.length + 1 : photos.length,
                    itemBuilder: (context, index) {
                      if (index < photos.length) {
                        final pUrl = photos[index] as String;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border_subtle),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: _getCacheBusterUrl(pUrl),
                              key: UniqueKey(),
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              maxWidthDiskCache: 400,
                              maxHeightDiskCache: 400,
                              placeholder: (context, url) => Container(
                                color: AppTheme.surface_interactive,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppTheme.accent_primary, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, error, stackTrace) => Container(
                                color: AppTheme.surface_interactive,
                                child: const Icon(Icons.broken_image_outlined, color: AppTheme.text_tertiary),
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Dashed / Stroke + Add Photo action slot
                        return GestureDetector(
                          onTap: _uploadNewPhoto,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface_interactive,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.border_subtle,
                                width: 1.5,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: AppTheme.accent_primary, size: 28),
                                SizedBox(height: 2),
                                Text(
                                  '+ Photo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accent_primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Intent Goal Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface_card,
                borderRadius: BorderRadius.circular(AppTheme.radius_md),
                border: Border.all(color: AppTheme.border_subtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent_primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite_outline, color: AppTheme.accent_primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Relationship Goal',
                          style: TextStyle(fontSize: 12, color: AppTheme.text_secondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          intent == 'casual'
                              ? 'Casual Conversations & Chai'
                              : intent == 'serious'
                                  ? 'Serious Marriage Intent'
                                  : 'Friendship & Networking',
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About Me Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface_card,
                borderRadius: BorderRadius.circular(AppTheme.radius_md),
                border: Border.all(color: AppTheme.border_subtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About Me',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(fontSize: 13, color: AppTheme.text_secondary, height: 1.4),
                  ),
                  const Divider(color: AppTheme.border_subtle, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gender', style: TextStyle(color: AppTheme.text_secondary)),
                      Text(gender, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Unified Settings Grouping Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface_card,
                borderRadius: BorderRadius.circular(AppTheme.radius_md),
                border: Border.all(color: AppTheme.border_subtle),
              ),
              child: Column(
                children: [
                  if ((_profileData?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString().toLowerCase().trim() == 'kshtriyaanubhav9120@gmail.com' || _profileData?['is_admin'] == true) ...[
                    _buildActionTile(
                      icon: Icons.admin_panel_settings_outlined,
                      iconColor: AppTheme.accent_boost_gold,
                      title: 'Admin Verification Panel',
                      subtitle: 'Review and approve pending selfie videos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminVerificationScreen()),
                        );
                      },
                    ),
                    const Divider(color: AppTheme.border_subtle, height: 1),
                  ],
                  _buildActionTile(
                    icon: Icons.badge_outlined,
                    iconColor: AppTheme.accent_verified_blue,
                    title: 'Edit Profile & Verification',
                    subtitle: 'Manage bio, photos, and video verification',
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                      );
                      if (updated == true) {
                        _fetchProfile();
                      }
                    },
                  ),
                  const Divider(color: AppTheme.border_subtle, height: 1),
                  _buildActionTile(
                    icon: Icons.block_outlined,
                    iconColor: AppTheme.status_destructive,
                    title: 'Blocked Users',
                    subtitle: 'View and unblock restricted profiles',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
                      );
                    },
                  ),
                  const Divider(color: AppTheme.border_subtle, height: 1),
                  _buildActionTile(
                    icon: Icons.mail_outline_rounded,
                    iconColor: AppTheme.accent_boost_gold,
                    title: 'Enhancement & Feedback',
                    subtitle: 'Send feedback and suggestions directly',
                    onTap: () {
                      final userId = _profileData?['id'] ?? _profileData?['user_id'] ?? FirebaseAuth.instance.currentUser?.uid;
                      sendFeedbackEmail(userId: userId?.toString());
                    },
                  ),
                  const Divider(color: AppTheme.border_subtle, height: 1),
                  _buildActionTile(
                    icon: Icons.system_update_alt_rounded,
                    iconColor: AppTheme.status_online,
                    title: 'Check for App Updates',
                    subtitle: 'Download latest direct APK updates instantly',
                    onTap: () {
                      AppUpdateService.instance.checkForUpdate(context, showNoUpdateToast: true);
                    },
                  ),
                  const Divider(color: AppTheme.border_subtle, height: 1),
                  _buildActionTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: AppTheme.status_destructive,
                    titleColor: AppTheme.status_destructive,
                    title: 'Delete Account',
                    subtitle: 'Permanently erase your profile, photos, and chat history',
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openManageSubscriptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ManageSubscriptionsSheet(),
    ).then((_) => _fetchProfile());
  }

  Widget _buildManagePassesTile(BuildContext context, Map<String, dynamic>? activePasses) {
    int activeCount = 0;
    if (activePasses != null) {
      final now = DateTime.now().toUtc();
      bool isIsoActive(String? iso) {
        if (iso == null) return false;
        final dt = DateTime.tryParse(iso)?.toUtc();
        return dt != null && dt.isAfter(now);
      }

      if (activePasses['is_boosted'] == true || isIsoActive(activePasses['boost_expires_at'])) activeCount++;
      if (activePasses['has_direct_dm'] == true || activePasses['is_direct_dm_active'] == true || isIsoActive(activePasses['direct_dm_expires_at'])) activeCount++;
      if (activePasses['is_ad_free'] == true || isIsoActive(activePasses['ad_free_expires_at'])) activeCount++;
      if (activePasses['has_safe_bridge'] == true) activeCount++;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface_card,
        borderRadius: BorderRadius.circular(AppTheme.radius_md),
        border: Border.all(color: AppTheme.accent_primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent_primary.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent_primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.workspace_premium, color: AppTheme.accent_primary, size: 24),
        ),
        title: const Text(
          'Monetization & VIP Passes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          activeCount > 0 ? '$activeCount Active Pass${activeCount > 1 ? "es" : ""}' : 'Boost, Direct DM & VIP Pro',
          style: TextStyle(
            color: activeCount > 0 ? AppTheme.status_online : AppTheme.text_secondary,
            fontSize: 12,
            fontWeight: activeCount > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.text_tertiary, size: 14),
        onTap: () {
          _openManageSubscriptionsSheet(context);
        },
      ),
    );
  }
}
