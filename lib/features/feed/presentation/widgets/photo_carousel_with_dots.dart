import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

class PhotoCarouselWithDots extends StatefulWidget {
  final List<String> photos;
  final List<String> blurHashes;
  final bool isDark;
  final bool isKycVerified;
  final String locationTag;

  const PhotoCarouselWithDots({
    super.key,
    required this.photos,
    required this.blurHashes,
    required this.isDark,
    this.isKycVerified = false,
    this.locationTag = 'Saket, Ayodhya',
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
    final photoList = widget.photos.isNotEmpty ? widget.photos : [''];

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
              return Container(
                color: surfaceMuted,
                child: photo.isNotEmpty
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
                    : _buildFallback(pine),
              );
            },
          ),
          // Tap zones
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
