import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// 5-Slot Photo Grid: 1 Large Primary Anchor Avatar + 4 Candid Thumbnails
/// Supports real device Camera capture, Gallery picker, and removal
class FiveSlotPhotoGrid extends ConsumerWidget {
  final Future<void> Function(int slotNumber)? onSelectImage;

  const FiveSlotPhotoGrid({super.key, this.onSelectImage});

  Future<void> _handleXFileSelected(
    BuildContext context,
    WidgetRef ref,
    int slotNumber,
    XFile file,
    bool isDark,
  ) async {
    final bytes = await file.readAsBytes();
    final success = await ref
        .read(profileSetupControllerProvider.notifier)
        .processAndUploadBytes(
          slotNumber: slotNumber,
          rawBytes: bytes,
          localFallbackPath: file.path,
        );

    if (!success && context.mounted) {
      final error = ref.read(profileSetupControllerProvider).lastModerationError;
      if (error != null) {
        final bool isTextError = error.toLowerCase().contains('text detected') ||
            error.toLowerCase().contains('text');
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark
                ? DarkSanctuaryTokens.surfaceCard
                : LightSanctuaryTokens.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isTextError ? Icons.text_fields_outlined : Icons.shield_outlined,
                  color: const Color(0xFFE63946),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTextError ? 'Text Detected in Photo' : 'Sanctuary Safety Alert',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              error,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'I Understand',
                  style: TextStyle(
                    color: Color(0xFFE27D60),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleSlotTap(
    BuildContext context,
    WidgetRef ref,
    int slotNumber,
    String? currentFilePath,
  ) async {
    // If external handler provided (e.g. In unit tests), invoke it first
    if (onSelectImage != null) {
      await onSelectImage!(slotNumber);
      return;
    }

    final isDark = ref.read(themeProvider).activeTheme == SanctuaryTheme.dark;
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final textColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final picker = ImagePicker();

    // Show stylish Action Sheet
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  slotNumber == 1
                      ? 'Anchor Portrait (Primary Sanctuary Photo)'
                      : 'Candid Sanctuary Photo (Slot $slotNumber)',
                  style: AppTypography.bodySmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: accentColor),
                  title: Text('Take a Photo / Selfie', style: TextStyle(color: textColor, fontSize: 14)),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      final XFile? photo = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1080,
                        maxHeight: 1350,
                        imageQuality: 85,
                      );
                      if (photo != null && context.mounted) {
                        await _handleXFileSelected(context, ref, slotNumber, photo, isDark);
                      }
                    } catch (e) {
                      debugPrint('[FiveSlotPhotoGrid] Camera error: $e');
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: accentColor),
                  title: Text('Choose from Gallery', style: TextStyle(color: textColor, fontSize: 14)),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1080,
                        maxHeight: 1350,
                        imageQuality: 85,
                      );
                      if (image != null && context.mounted) {
                        await _handleXFileSelected(context, ref, slotNumber, image, isDark);
                      }
                    } catch (e) {
                      debugPrint('[FiveSlotPhotoGrid] Gallery error: $e');
                    }
                  },
                ),
                if (currentFilePath != null && currentFilePath.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref
                          .read(profileSetupControllerProvider.notifier)
                          .removePhotoSlot(slotNumber);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

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
              Row(
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  ),
                  const SizedBox(width: 6),
                  Text('Compressing...', style: TextStyle(fontSize: 11, color: accentColor)),
                ],
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
                context: context,
                ref: ref,
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
                          context: context,
                          ref: ref,
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
                          context: context,
                          ref: ref,
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
                          context: context,
                          ref: ref,
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
                          context: context,
                          ref: ref,
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
    required BuildContext context,
    required WidgetRef ref,
    required int slotNumber,
    required bool isAnchor,
    required double height,
    required String? filePath,
    required Color cardBg,
    required Color cardBorder,
    required Color accentColor,
    required Color mutedColor,
  }) {
    final imageProvider = resolveSanctuaryImageProvider(filePath);
    final hasValidImage = imageProvider != null;

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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleSlotTap(context, ref, slotNumber, filePath),
            child: hasValidImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(isAnchor, slotNumber, accentColor, mutedColor),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : _buildPlaceholder(isAnchor, slotNumber, accentColor, mutedColor),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isAnchor, int slotNumber, Color accentColor, Color mutedColor) {
    return Column(
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
    );
  }
}
