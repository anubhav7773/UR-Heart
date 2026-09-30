import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 4-Slot moments media grid for personal reflection photos
class MomentsMediaGrid extends StatelessWidget {
  final List<String> photos;
  final bool isDark;
  final void Function(int slotIndex) onReplaceSlot;

  const MomentsMediaGrid({
    super.key,
    required this.photos,
    required this.isDark,
    required this.onReplaceSlot,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final slotBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.chipBackground;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sacred Moments (4 Slots)',
                style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
              ),
              Text(
                'WebP · <100KB R2',
                style: AppTypography.bodySmall.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final hasPhoto = index < photos.length && photos[index].isNotEmpty;
              final photo = hasPhoto ? photos[index] : '';

              return GestureDetector(
                onTap: () => onReplaceSlot(index),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: slotBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? DarkSanctuaryTokens.inputBorder
                          : LightSanctuaryTokens.inputBorder,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPhoto)
                        _buildPhotoView(photo, mutedColor, index)
                      else
                        _buildPlaceholder(mutedColor, index),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            hasPhoto ? Icons.edit_rounded : Icons.add_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoView(String pathOrUrl, Color mutedColor, int index) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(mutedColor, index),
      );
    }
    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(mutedColor, index),
      );
    }
    return _buildPlaceholder(mutedColor, index);
  }

  Widget _buildPlaceholder(Color mutedColor, int index) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 28,
            color: mutedColor,
          ),
          const SizedBox(height: 6),
          Text(
            'Moment #${index + 1}',
            style: AppTypography.bodySmall.copyWith(
              color: mutedColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
