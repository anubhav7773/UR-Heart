import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import 'package:ur_heart/core/utils/image_compressor.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/features/home/presentation/main_shell_screen.dart';
import 'package:ur_heart/features/kyc/data/kyc_repository.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';

/// Screen 2: 5-Photo Upload, Live OCR Warning & KYC Viewfinder
/// Spec: URH-UIX-009 Section 3 Screen 2
class PhotoUploadScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onContinue;

  const PhotoUploadScreen({
    super.key,
    this.lang = 'en',
    this.onContinue,
  });

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> with SecureScreenMixin {
  final KycRepository _kycRepository = KycRepository();
  final ImagePicker _picker = ImagePicker();

  // Slots 1 to 5 mapping (slot 1 is Hero)
  final Map<int, File?> _photos = {};
  final Map<int, String?> _networkPhotoUrls = {};
  final Map<int, bool> _isScanning = {};
  final Map<int, bool> _isVerified = {};
  final Map<int, String?> _errors = {};

  // Video KYC state
  bool _isVideoScanning = false;
  bool _isVideoVerified = false;
  String? _videoStatusText;

  @override
  void initState() {
    super.initState();
    _loadExistingPhotos();
  }

  Future<void> _loadExistingPhotos() async {
    try {
      final profile = await ProfileRepository().getProfile();
      if (profile != null && profile.photos.isNotEmpty && mounted) {
        setState(() {
          for (final p in profile.photos) {
            if (p.slotIndex >= 1 && p.slotIndex <= 5 && p.photoUrl.isNotEmpty) {
              _networkPhotoUrls[p.slotIndex] = p.photoUrl;
              _isVerified[p.slotIndex] = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error preloading photos in PhotoUploadScreen: $e');
    }
  }

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  Future<void> _pickAndScanPhoto(int slotIndex) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: URHeartColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: URHeartColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Real Profile Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Zero-tolerance AI & Anti-Leak Policy: Must be a 100% clean photo with no text, usernames, watermarks, or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: URHeartColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: URHeartColors.brandPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: URHeartColors.brandPrimary),
                ),
                title: const Text(
                  'Take Live Camera Photo (Recommended)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Guarantees authentic camera capture',
                  style: TextStyle(color: URHeartColors.brandSecondary, fontSize: 11),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: URHeartColors.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.white70),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Must be unedited raw camera photo',
                  style: TextStyle(color: URHeartColors.textMuted, fontSize: 11),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
        preferredCameraDevice: CameraDevice.front,
      );

      if (picked == null) return;

      final rawFile = File(picked.path);

      // Client-side compression to WebP to guarantee small payload
      File uploadFile = rawFile;
      String currentBlurHash = '';
      try {
        final processed = await ImageOptimizer.processPhoto(rawFile);
        if (processed != null) {
          final tempDir = Directory.systemTemp;
          final compressedFile = File(
            '${tempDir.path}/slot_${slotIndex}_${DateTime.now().millisecondsSinceEpoch}.webp',
          );
          uploadFile = await compressedFile.writeAsBytes(processed.compressedBytes);
          currentBlurHash = processed.blurHash;
        }
      } catch (e) {
        debugPrint('Image compression fallback to raw file: $e');
      }

      setState(() {
        _photos[slotIndex] = uploadFile;
        _isScanning[slotIndex] = true;
        _errors[slotIndex] = null;
      });

      // 1. Call backend scan-photo anti-leak OCR
      final scanResult = await _kycRepository.scanPhoto(uploadFile);
      if (scanResult['status'] != 'clean') {
        throw Exception(scanResult['message'] ?? 'Photo failed anti-leak scan');
      }

      // 2. Upload compressed WebP photo to Supabase storage & persist to user_photos
      final uploadResult = await _kycRepository.uploadPhoto(
        photoFile: uploadFile,
        slotIndex: slotIndex,
        blurHash: currentBlurHash,
      );

      if (mounted) {
        setState(() {
          _isScanning[slotIndex] = false;
          _isVerified[slotIndex] = true;
          if (uploadResult['photo_url'] != null) {
            _networkPhotoUrls[slotIndex] = uploadResult['photo_url'] as String;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: URHeartColors.statusSuccess,
            content: Text('Slot $slotIndex photo passed anti-leak scan & saved!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning[slotIndex] = false;
          _isVerified[slotIndex] = false;
          _errors[slotIndex] = e.toString().replaceAll('Exception: ', '');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: URHeartColors.statusDanger,
            content: Text('Slot $slotIndex scan failed: ${_errors[slotIndex]}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _recordKycVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(seconds: 4),
      );

      if (picked == null) return;

      final file = File(picked.path);

      setState(() {
        _isVideoScanning = true;
        _videoStatusText = 'Analyzing face & speech with AI...';
      });

      String? userName;
      try {
        userName = FirebaseAuth.instance.currentUser?.displayName;
      } catch (_) {}

      final result = await _kycRepository.submitKycVideo(
        videoFile: file,
        userName: userName,
      );

      if (mounted) {
        final bool isAccepted = result['verified'] == true ||
            result['status'] == 'auto_verified' ||
            result['status'] == 'verified' ||
            result['status'] == 'queued_for_admin_review';

        final bool isAutoApproved = result['status'] == 'auto_verified' || result['status'] == 'verified' || result['verified'] == true;

        setState(() {
          _isVideoScanning = false;
          _isVideoVerified = isAccepted;
          _videoStatusText = isAutoApproved
              ? 'Verified by AI (${((result['confidence'] ?? 0.95) * 100).toInt()}% match)'
              : 'KYC Submitted (Queued for admin review)';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isAutoApproved ? URHeartColors.statusSuccess : URHeartColors.accentGold,
            content: Text(_videoStatusText!),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanError = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isVideoScanning = false;
          _videoStatusText = 'Video upload: $cleanError';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: URHeartColors.statusDanger,
            content: Text('Video verification: $cleanError'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasHeroPhoto = _photos[1] != null || (_networkPhotoUrls[1]?.isNotEmpty == true);
    final int secondaryPhotoCount = [2, 3, 4, 5]
        .where((s) => _photos[s] != null || (_networkPhotoUrls[s]?.isNotEmpty == true))
        .length;
    final bool hasMinPhotos = hasHeroPhoto && secondaryPhotoCount >= 2;
    final bool isReadyToExplore = hasMinPhotos && _isVideoVerified;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: URHeartColors.canvasBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload 5 Profile Photos / फ़ोटो',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                _t('stepTwoOfThree'),
                style: const TextStyle(fontSize: 12, color: URHeartColors.textSecondary),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // High-Visibility Anti-Leak Warning Banner
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: URHeartColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: URHeartColors.brandPrimary, width: 1.2),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_rounded, color: URHeartColors.brandPrimary, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🛡️ Zero-Tolerance AI & Anti-Leak AI: Only 100% clean, raw camera photos showing your clear, unobstructed face are accepted. AI-generated text, Instagram/WhatsApp handles, watermarks, and heavy filters will be rejected automatically.',
                        style: TextStyle(
                          color: URHeartColors.textPrimary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Slot 1: Hero Display Photo Card (220px height)
              _buildHeroSlot(),
              const SizedBox(height: 12),

              // Slots 2-5: 2x2 Grid for Secondary Lifestyle Photos
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemBuilder: (context, index) {
                  final slot = index + 2;
                  return _buildSecondarySlot(slot);
                },
              ),
              const SizedBox(height: 16),

              // 5-Second Video KYC Viewfinder Card
              _buildVideoKycCard(),
              const SizedBox(height: 24),

              // Floating Bottom CTA
              SizedBox(
                height: URHeartTheme.minTouchTarget,
                child: ElevatedButton(
                  onPressed: isReadyToExplore
                      ? () {
                          if (widget.onContinue != null) {
                            widget.onContinue!();
                          } else {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => MainShellScreen(lang: widget.lang),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReadyToExplore
                        ? URHeartColors.brandPrimary
                        : const Color(0xFF22222C),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF22222C),
                    disabledForegroundColor: const Color(0xFF636375),
                  ),
                  child: Text(
                    isReadyToExplore
                        ? _t('verifyContinue')
                        : 'Complete Photos & Video KYC to Unlock',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!isReadyToExplore) ...[
                const SizedBox(height: 8),
                Text(
                  !hasHeroPhoto
                      ? '⚠️ Step 1: Please upload Slot 1 Hero Photo.'
                      : (secondaryPhotoCount < 2
                          ? '⚠️ Step 2: Please upload at least 2 lifestyle photos ($secondaryPhotoCount/2 uploaded).'
                          : '⚠️ Step 3: Please record 5-second video KYC above.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeroSlot() {
    final photo = _photos[1];
    final networkUrl = _networkPhotoUrls[1];
    final bool hasPhoto = photo != null || (networkUrl != null && networkUrl.isNotEmpty);
    final isScanning = _isScanning[1] == true;
    final isVerified = _isVerified[1] == true;

    ImageProvider? imageProvider;
    if (photo != null) {
      imageProvider = FileImage(photo);
    } else if (networkUrl != null && networkUrl.isNotEmpty) {
      imageProvider = CachedNetworkImageProvider(networkUrl);
    }

    return InkWell(
      onTap: () => _pickAndScanPhoto(1),
      borderRadius: URHeartTheme.radiusCard,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: URHeartColors.cardSurface,
          borderRadius: URHeartTheme.radiusCard,
          border: Border.all(
            color: isVerified
                ? URHeartColors.statusSuccess
                : URHeartColors.brandPrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          image: imageProvider != null
              ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!hasPhoto)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded, color: URHeartColors.brandPrimary, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    _t('profileHero'),
                    style: const TextStyle(
                      color: URHeartColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to upload display picture',
                    style: TextStyle(color: URHeartColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            if (isScanning)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: URHeartColors.brandPrimary),
                      SizedBox(height: 8),
                      Text(
                        'Scanning OCR anti-leak...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            if (isVerified)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: URHeartColors.statusSuccess.withValues(alpha: 0.9),
                    borderRadius: URHeartTheme.radiusPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _t('ocrVerifiedTag'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
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

  Widget _buildSecondarySlot(int slot) {
    final photo = _photos[slot];
    final networkUrl = _networkPhotoUrls[slot];
    final bool hasPhoto = photo != null || (networkUrl != null && networkUrl.isNotEmpty);
    final isScanning = _isScanning[slot] == true;
    final isVerified = _isVerified[slot] == true;

    ImageProvider? imageProvider;
    if (photo != null) {
      imageProvider = FileImage(photo);
    } else if (networkUrl != null && networkUrl.isNotEmpty) {
      imageProvider = CachedNetworkImageProvider(networkUrl);
    }

    return InkWell(
      onTap: () => _pickAndScanPhoto(slot),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: URHeartColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isVerified ? URHeartColors.statusSuccess : URHeartColors.surfaceRaised,
          ),
          image: imageProvider != null
              ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!hasPhoto)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: URHeartColors.textSecondary, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    'Slot $slot',
                    style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            if (isScanning)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: URHeartColors.brandPrimary),
                  ),
                ),
              ),
            if (isVerified)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: URHeartColors.statusSuccess,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoKycCard() {
    return InkWell(
      onTap: _recordKycVideo,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: URHeartColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isVideoVerified ? URHeartColors.statusSuccess : URHeartColors.surfaceRaised,
          ),
        ),
        child: Row(
          children: [
            // Circular Selfie Preview Box
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: URHeartColors.surfaceRaised,
                border: Border.all(
                  color: _isVideoVerified ? URHeartColors.statusSuccess : URHeartColors.brandSecondary,
                  width: 1.5,
                ),
              ),
              child: _isVideoScanning
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: URHeartColors.brandSecondary),
                    )
                  : Icon(
                      _isVideoVerified ? Icons.verified_user_rounded : Icons.videocam_rounded,
                      color: _isVideoVerified ? URHeartColors.statusSuccess : URHeartColors.brandSecondary,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('fiveSecVideoTitle'),
                    style: const TextStyle(
                      color: URHeartColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _videoStatusText ?? _t('fiveSecVideoSub'),
                    style: TextStyle(
                      color: _isVideoVerified ? URHeartColors.statusSuccess : URHeartColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: URHeartColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
