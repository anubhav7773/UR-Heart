import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import '../../feed/presentation/feed_screen.dart';

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

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
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
                  color: URHeartColors.statusDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: URHeartColors.statusDanger, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: URHeartColors.statusDanger, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t('antiLeakNotice'),
                        style: const TextStyle(
                          color: URHeartColors.textPrimary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Slot 1: Hero Display Photo Card (220px height)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: URHeartColors.cardSurface,
                  borderRadius: URHeartTheme.radiusCard,
                  border: Border.all(
                    color: URHeartColors.brandPrimary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
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
                      ],
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: URHeartColors.statusSuccess.withValues(alpha: 0.2),
                          borderRadius: URHeartTheme.radiusPill,
                          border: Border.all(color: URHeartColors.statusSuccess),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: URHeartColors.statusSuccess, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _t('ocrVerifiedTag'),
                              style: const TextStyle(
                                color: URHeartColors.statusSuccess,
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
                  return Container(
                    decoration: BoxDecoration(
                      color: URHeartColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: URHeartColors.surfaceRaised),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, color: URHeartColors.textSecondary, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'Slot ${index + 2}',
                            style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 5-Second Video KYC Viewfinder Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: URHeartColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: URHeartColors.surfaceRaised),
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
                        border: Border.all(color: URHeartColors.brandSecondary, width: 1.5),
                      ),
                      child: const Icon(Icons.videocam_rounded, color: URHeartColors.brandSecondary, size: 28),
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
                            _t('fiveSecVideoSub'),
                            style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Floating Bottom CTA
              SizedBox(
                height: URHeartTheme.minTouchTarget,
                child: ElevatedButton(
                  onPressed: widget.onContinue ??
                      () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => FeedScreen(lang: widget.lang),
                          ),
                        );
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: URHeartColors.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _t('verifyContinue'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
