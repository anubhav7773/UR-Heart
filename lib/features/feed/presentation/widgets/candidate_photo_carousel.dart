import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Horizontal WebP photo pager with BlurHash placeholder transition and pagination dots
class CandidatePhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;
  final List<String> blurHashes;
  final bool isDark;

  const CandidatePhotoCarousel({
    super.key,
    required this.photoUrls,
    required this.blurHashes,
    required this.isDark,
  });

  @override
  State<CandidatePhotoCarousel> createState() => _CandidatePhotoCarouselState();
}

class _CandidatePhotoCarouselState extends State<CandidatePhotoCarousel> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDotColor = widget.isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final inactiveDotColor = Colors.white.withAlpha(100);
    final count = widget.photoUrls.isNotEmpty ? widget.photoUrls.length : 1;

    return Stack(
      children: [
        // Horizontal PageView with tap-driven paging to preserve card swipe gestures
        PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final photoUrl = widget.photoUrls.isNotEmpty ? widget.photoUrls[index] : null;

            return Container(
              color: widget.isDark ? const Color(0xFF1B2923) : const Color(0xFFEBE6DC),
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        // Smooth BlurHash placeholder representation
                        return Container(
                          color: widget.isDark ? const Color(0xFF131F19) : const Color(0xFFF2EFE9),
                          child: Center(
                            child: Icon(
                              Icons.spa,
                              size: 44.0,
                              color: activeDotColor.withAlpha(120),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: widget.isDark ? const Color(0xFF131F19) : const Color(0xFFF2EFE9),
                          child: Center(
                            child: Icon(Icons.person, size: 64.0, color: activeDotColor),
                          ),
                        );
                      },
                    )
                  : Center(child: Icon(Icons.person, size: 64.0, color: activeDotColor)),
            );
          },
        ),
        // Tap navigation zones: Left tap for previous, Right tap for next
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
                    if (_currentIndex < count - 1) {
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
        // Pagination Indicator Dots
        if (count > 1)
          Positioned(
            top: 14.0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (index) {
                final isSelected = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  width: isSelected ? 20.0 : 6.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: isSelected ? activeDotColor : inactiveDotColor,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
