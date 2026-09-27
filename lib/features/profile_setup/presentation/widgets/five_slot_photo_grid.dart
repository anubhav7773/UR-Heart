import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// 5-Slot Photo Grid: 1 Large Primary Anchor Avatar + 4 Candid Thumbnails
class FiveSlotPhotoGrid extends ConsumerWidget {
  final Future<void> Function(int slotNumber)? onSelectImage;

  const FiveSlotPhotoGrid({super.key, this.onSelectImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileSetupControllerProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SANCTUARY PHOTOS (5 DISCRETE SLOTS)',
              style: AppTypography.accordionCategory.copyWith(color: mutedColor),
            ),
            if (profileState.isUploadingPhoto)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
              ),
          ],
        ),
        const SizedBox(height: 10.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slot 1: Primary Anchor Avatar (Large)
            Expanded(
              flex: 5,
              child: _buildSlotContainer(
                slotNumber: 1,
                isAnchor: true,
                height: 200.0,
                filePath: profileState.photoSlots[1],
                cardBg: cardBg,
                cardBorder: cardBorder,
                accentColor: accentColor,
                mutedColor: mutedColor,
              ),
            ),
            const SizedBox(width: 10.0),
            // Slots 2-5: 4 Candid Slots Grid (2x2)
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSlotContainer(
                          slotNumber: 2,
                          isAnchor: false,
                          height: 95.0,
                          filePath: profileState.photoSlots[2],
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          accentColor: accentColor,
                          mutedColor: mutedColor,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildSlotContainer(
                          slotNumber: 3,
                          isAnchor: false,
                          height: 95.0,
                          filePath: profileState.photoSlots[3],
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          accentColor: accentColor,
                          mutedColor: mutedColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSlotContainer(
                          slotNumber: 4,
                          isAnchor: false,
                          height: 95.0,
                          filePath: profileState.photoSlots[4],
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          accentColor: accentColor,
                          mutedColor: mutedColor,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildSlotContainer(
                          slotNumber: 5,
                          isAnchor: false,
                          height: 95.0,
                          filePath: profileState.photoSlots[5],
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          accentColor: accentColor,
                          mutedColor: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotContainer({
    required int slotNumber,
    required bool isAnchor,
    required double height,
    required String? filePath,
    required Color cardBg,
    required Color cardBorder,
    required Color accentColor,
    required Color mutedColor,
  }) {
    final hasImage = filePath != null && filePath.isNotEmpty;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isAnchor ? accentColor.withOpacity(0.6) : cardBorder,
          width: isAnchor ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: InkWell(
          onTap: () {
            if (onSelectImage != null) {
              onSelectImage?.call(slotNumber);
            }
          },
          child: hasImage
              ? Image.file(
                  File(filePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAnchor ? Icons.face_retouching_natural : Icons.add_photo_alternate_outlined,
                      size: isAnchor ? 28.0 : 20.0,
                      color: isAnchor ? accentColor : mutedColor,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      isAnchor ? 'Anchor Slot' : 'Slot $slotNumber',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isAnchor ? accentColor : mutedColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
