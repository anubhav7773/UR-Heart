import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../settings/blocked_users_screen.dart';
import '../subscription/subscription_sheet.dart';
import '../../screens/admin_verification_screen.dart';
import '../../screens/activity_screen.dart';
import '../../core/utils/feedback_helper.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/image_guard_service.dart';
import 'edit_profile_screen.dart';
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
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFE91E63)),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from RuralHeart?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
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
      backgroundColor: Colors.grey[950],
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
                          icon: const Icon(Icons.close, color: Colors.grey),
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
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
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
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
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
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[900],
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
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[900],
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
                          label: const Text('☕ Casual Chai'),
                          selected: currentIntent == 'casual',
                          selectedColor: const Color(0xFFE91E63),
                          onSelected: (sel) => setModalState(() => currentIntent = 'casual'),
                        ),
                        ChoiceChip(
                          label: const Text('💍 Serious Marriage'),
                          selected: currentIntent == 'serious',
                          selectedColor: const Color(0xFFE91E63),
                          onSelected: (sel) => setModalState(() => currentIntent = 'serious'),
                        ),
                        ChoiceChip(
                          label: const Text('🤝 Friendship'),
                          selected: currentIntent == 'friendship',
                          selectedColor: const Color(0xFFE91E63),
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
                        backgroundColor: const Color(0xFFE91E63),
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
                backgroundColor: Colors.redAccent,
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
          // Force evict Flutter NetworkImage memory & live image caches
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
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video verification notice: ${e.toString()}'),
            backgroundColor: Colors.amber[800],
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
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Verified',
                    style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your identity & selfie video are approved with the Blue Badge.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
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
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Under Review',
                    style: TextStyle(fontSize: 14, color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your selfie video has been submitted. Moderation review takes up to 24h.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
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
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Rejected',
                        style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your selfie video did not pass clarity guidelines. Please record again.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
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
                icon: const Icon(Icons.videocam, size: 18),
                label: const Text('Record Selfie Video Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
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
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE91E63).withValues(alpha: 0.2),
              Colors.deepPurple.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified, color: Color(0xFFE91E63), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Get Verified & Stand Out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Record a quick 5-second selfie video to earn the blue checkmark badge & get 3x more matches!',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startVideoVerification,
                icon: const Icon(Icons.videocam, size: 18),
                label: const Text('Verify Now (5-Sec Selfie)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditProfileSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Profile Main Avatar Card with Cache-Busting Network Image
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE91E63), width: 3),
                      color: Colors.grey[900],
                    ),
                    child: ClipOval(
                      child: mainPhoto.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _getCacheBusterUrl(mainPhoto),
                              key: UniqueKey(),
                              fit: BoxFit.cover,
                              width: 130,
                              height: 130,
                              memCacheWidth: 260,
                              memCacheHeight: 260,
                              maxWidthDiskCache: 600,
                              maxHeightDiskCache: 600,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: CircularProgressIndicator(color: Color(0xFFE91E63), strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, error, stackTrace) =>
                                   const Icon(Icons.person, size: 70, color: Colors.grey),
                            )
                          : const Icon(Icons.person, size: 70, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _uploadNewPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE91E63),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // User Name & Verified Badge (Only if verified)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  age != null && age > 0 ? '$fullName, $age' : fullName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: Colors.blue, size: 22),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Active Now Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Active Now',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  $areaName',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Active Super Boost Countdown Badge
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

            // Location Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(areaName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Super Boost (₹29) / VIP Promotion Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE91E63).withValues(alpha: 0.15),
                    Colors.amber.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, color: Colors.black87, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ 10x Visibility Super Boost',
                          style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isBoosted ? 'Active on your profile now! 🔥' : 'Be #1 in candidate feeds for 1 hour (₹29)',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const SubscriptionSheet(),
                      ).then((_) => _fetchProfile());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isBoosted ? 'Extend 🔥' : 'Boost ₹29', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Video Verification Status Card
            _buildVerificationCard(isVerified, verificationStatus),
            const SizedBox(height: 16),

            // Intent Goal Badge Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.amber, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Relationship Goal',
                          style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          intent == 'casual'
                              ? '☕ Casual Chai & Conversations'
                              : intent == 'serious'
                                  ? '💍 Serious Marriage Intent'
                                  : '🤝 Friendship & Networking',
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profile Details Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About Me',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                  ),
                  const Divider(color: Colors.white12, height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gender', style: TextStyle(color: Colors.grey)),
                      Text(gender, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Verification Status', style: TextStyle(color: Colors.grey)),
                      Row(
                        children: [
                          Icon(Icons.shield, color: Colors.greenAccent, size: 16),
                          SizedBox(width: 4),
                          Text('Verified Member', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Settings Action Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if ((_profileData?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString().toLowerCase().trim() == 'kshtriyaanubhav9120@gmail.com' || _profileData?['is_admin'] == true) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade900.withValues(alpha: 0.7),
                            const Color(0xFFE91E63).withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE91E63), width: 1.5),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 28),
                        title: const Text('🛡️ Admin Verification Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Review and approve pending selfie videos', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminVerificationScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                  ListTile(
                    tileColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.history_toggle_off, color: Color(0xFFE91E63)),
                    title: const Text('Activity (Matches / Liked / Passed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('View your matches, likes, and passes history', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ActivityScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.verified_user, color: Colors.blueAccent),
                    title: const Text('Edit Profile & Video Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Get official Verified Blue Tick badge ✓', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.block, color: Colors.redAccent),
                    title: const Text('Blocked Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('View and unblock restricted profiles', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                    title: const Text('Suggest an Enhancement / Feedback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Got ideas to improve the app? Email the creator directly', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      final userId = _profileData?['id'] ?? _profileData?['user_id'] ?? FirebaseAuth.instance.currentUser?.uid;
                      sendFeedbackEmail(userId: userId?.toString(), appVersion: 'v1.0.0-release');
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.system_update_rounded, color: Colors.greenAccent),
                    title: const Text('Check for App Updates 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Download latest direct APK updates instantly', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      AppUpdateService.instance.checkForUpdate(context, showNoUpdateToast: true);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Photos Grid Gallery
            if (photos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Photos (${photos.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(icon: const Icon(Icons.add_a_photo, color: Color(0xFFE91E63), size: 22), onPressed: _uploadNewPhoto),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final pUrl = photos[index] as String;
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.grey[900],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: _getCacheBusterUrl(pUrl),
                          key: UniqueKey(),
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          maxWidthDiskCache: 400,
                          maxHeightDiskCache: 400,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: CircularProgressIndicator(color: Color(0xFFE91E63), strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, error, stackTrace) => Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
