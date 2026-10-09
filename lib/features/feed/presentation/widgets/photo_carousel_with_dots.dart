import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

class PhotoCarouselWithDots extends StatefulWidget {
  final List<String> photos;
  final List<String> blurHashes;
  final bool isDark;
  final bool isKycVerified;
  final String locationTag;
  final void Function(int index)? onPhotoTap;
  final bool isPhotoVeiled;
  final bool isPhotoUnlocked;
  final String photoRevealStatus;
  final VoidCallback? onRequestReveal;

  const PhotoCarouselWithDots({
    super.key,
    required this.photos,
    required this.blurHashes,
    required this.isDark,
    this.isKycVerified = false,
    this.locationTag = 'Saket, Ayodhya',
    this.onPhotoTap,
    this.isPhotoVeiled = false,
    this.isPhotoUnlocked = false,
    this.photoRevealStatus = 'none',
    this.onRequestReveal,
  });

  @override
  State<PhotoCarouselWithDots> createState() => _PhotoCarouselWithDotsState();
}

class _PhotoCarouselWithDotsState extends State<PhotoCarouselWithDots> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pine = widget.isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final surfaceMuted = widget.isDark
        ? DarkSanctuaryTokens.surfaceMuted
        : LightSanctuaryTokens.surfaceMuted;
    final validPhotos = widget.photos.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final photoList = validPhotos.isNotEmpty ? validPhotos : [''];

    final isVeiled = widget.isPhotoVeiled && !widget.isPhotoUnlocked;

    return SizedBox(
      height: 380,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photoList.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final rawPhoto = photoList[index].trim();
              String photo = rawPhoto;
              if (photo.startsWith('/api/v1/') || photo.startsWith('/storage/')) {
                photo = 'https://urheart.asiverticals.me$photo';
              }
              Widget imageWidget = photo.isNotEmpty
                  ? (photo.startsWith('http://') || photo.startsWith('https://')
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => _buildFallback(pine),
                        )
                      : (File(photo).existsSync()
                          ? Image.file(
                              File(photo),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => _buildFallback(pine),
                            )
                          : _buildFallback(pine)))
                  : _buildFallback(pine);

              if (isVeiled) {
                imageWidget = ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: imageWidget,
                );
              }

              return Container(
                color: surfaceMuted,
                child: imageWidget,
              );
            },
          ),
          if (isVeiled)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.38),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD97746).withValues(alpha: 0.2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.visibility_off_rounded,
                              color: Color(0xFFE88A58),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sacred Photo Veil',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Portrait veiled for analog privacy.\nUnveils with mutual consent.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (widget.photoRevealStatus == 'pending')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_top_rounded, color: Color(0xFF2ECC71), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Reveal Request Sent 🕊️',
                                  style: TextStyle(
                                    color: Color(0xFF2ECC71),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (widget.photoRevealStatus == 'declined')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'Reveal Request Declined',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97746),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: widget.onRequestReveal,
                            icon: const Icon(Icons.favorite_border, size: 15),
                            label: const Text(
                              'Request Photo Reveal 🕊️',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Tap zones
          if (!isVeiled)
            Positioned.fill(
              child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_currentIndex > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_currentIndex < photoList.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Pagination Dots
          if (photoList.length > 1)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(photoList.length, (idx) {
                  final isActive = idx == _currentIndex;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
          // Zoom / Lightbox Trigger Button
          if (widget.onPhotoTap != null && !isVeiled)
            Positioned(
              top: 26,
              right: 14,
              child: GestureDetector(
                onTap: () => widget.onPhotoTap?.call(_currentIndex),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                ),
              ),
            ),
          // Location & KYC Badge Overlay
          Positioned(
            bottom: 14,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me_outlined, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    widget.locationTag,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(Color accent) {
    return Center(
      child: Icon(Icons.person, size: 64, color: accent.withValues(alpha: 0.4)),
    );
  }
}
