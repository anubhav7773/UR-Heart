import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 4-Slot moments editor grid with direct Firebase uploads (< 160 lines)
class MomentsEditorGrid extends StatelessWidget {
  final List<String>? moments;
  final List<String>? photos;
  final bool isDark;
  final void Function(int slotNumber)? onSlotTap;
  final void Function(int slotIndex)? onReplaceSlot;

  const MomentsEditorGrid({
    super.key,
    this.moments,
    this.photos,
    required this.isDark,
    this.onSlotTap,
    this.onReplaceSlot,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePhotos = moments ?? photos ?? const [];
    final cardBg = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final slotBg = isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.chipBackground;
    final accentColor = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.terracottaAccent;

    void handleTap(int index) {
      if (onSlotTap != null) {
        onSlotTap!(index);
      } else if (onReplaceSlot != null) {
        onReplaceSlot!(index);
      }
    }

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
                'WebP · <100KB Firebase',
                style: AppTypography.bodySmall.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final hasPhoto = index < effectivePhotos.length && effectivePhotos[index].isNotEmpty;
              final photo = hasPhoto ? effectivePhotos[index] : '';
              return GestureDetector(
                onTap: () => handleTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: slotBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasPhoto ? accentColor.withValues(alpha: 0.5) : cardBorder,
                      width: 1,
                    ),
                  ),
                  child: hasPhoto
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: photo.startsWith('http')
                                  ? Image.network(
                                      photo,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: cardBorder,
                                        child: const Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
                                      ),
                                    )
                                  : (File(photo).existsSync()
                                      ? Image.file(
                                          File(photo),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: cardBorder,
                                            child: const Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
                                          ),
                                        )
                                      : Container(
                                          color: cardBorder,
                                          child: const Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
                                        )),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.refresh, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 28, color: mutedColor),
                            const SizedBox(height: 6),
                            Text(
                              'Slot ${index + 1}',
                              style: TextStyle(color: mutedColor, fontSize: 11),
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
}
