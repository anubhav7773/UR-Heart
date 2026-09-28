import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/persona_controller.dart';
import '../widgets/locked_credentials_card.dart';
import '../widgets/moments_media_grid.dart';
import '../widgets/persona_header_card.dart';
import '../widgets/persona_tabs_header.dart';
import '../widgets/preferences_slider_card.dart';

/// Screen 11: My Persona View & Editor
class MyPersonaScreen extends ConsumerWidget {
  static const String routeName = '/persona';

  const MyPersonaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;
    final state = ref.watch(personaControllerProvider);
    final notifier = ref.read(personaControllerProvider.notifier);

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    ref.listen(personaControllerProvider, (_, next) {
      if (next.successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage ?? ''),
            duration: const Duration(seconds: 2),
            backgroundColor: isDark
                ? DarkSanctuaryTokens.secondaryPine
                : LightSanctuaryTokens.primaryPine,
          ),
        );
        notifier.clearBanner();
      }
      if (next.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? ''),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.redAccent,
          ),
        );
        notifier.clearBanner();
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'My Persona',
          style: AppTypography.titleH1.copyWith(
            fontSize: 22,
            color: headlineColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: headlineColor),
            tooltip: 'Sanctuary Settings',
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonaTabsHeader(activeIndex: 0, isDark: isDark),
              PersonaHeaderCard(
                profile: state.profile,
                isDark: isDark,
                onEditAvatar: () =>
                    _showPhotoUploadModal(context, ref, isDark, 0, isAvatar: true),
              ),
              MomentsMediaGrid(
                photos: state.profile.momentPhotos,
                isDark: isDark,
                onReplaceSlot: (slot) =>
                    _showPhotoUploadModal(context, ref, isDark, slot, isAvatar: false),
              ),
              LockedCredentialsCard(
                profile: state.profile,
                isDark: isDark,
              ),
              PreferencesSliderCard(
                profile: state.profile,
                isDark: isDark,
                isPolishing: state.isPolishing,
                isSaving: state.isSaving,
                onUpdateGps: notifier.refreshLocation,
                onPolishBio: notifier.polishBioWithGroq,
                onBioChanged: notifier.updateBio,
                onProfessionChanged: notifier.updateProfession,
                onEducationChanged: notifier.updateEducation,
                onAgeRangeChanged: notifier.updateAgeRange,
                onSaveChanges: notifier.saveProfile,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoUploadModal(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    int slotIndex, {
    required bool isAvatar,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark
          ? DarkSanctuaryTokens.surfaceCard
          : LightSanctuaryTokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAvatar
                    ? 'Update Sanctuary Avatar'
                    : 'Replace Sacred Moment #${slotIndex + 1}',
                style: AppTypography.titleH2.copyWith(
                  fontSize: 18,
                  color: isDark
                      ? DarkSanctuaryTokens.textHeadline
                      : LightSanctuaryTokens.textHeadline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Automatic WebP <100KB compression & OCR moderation applied.',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark
                      ? DarkSanctuaryTokens.textMuted
                      : LightSanctuaryTokens.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Capture with Camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndProcessPhoto(
                    context,
                    ref,
                    ImageSource.camera,
                    isAvatar: isAvatar,
                    slotIndex: slotIndex,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Select from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndProcessPhoto(
                    context,
                    ref,
                    ImageSource.gallery,
                    isAvatar: isAvatar,
                    slotIndex: slotIndex,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndProcessPhoto(
    BuildContext context,
    WidgetRef ref,
    ImageSource source, {
    required bool isAvatar,
    int slotIndex = 0,
  }) async {
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1350,
        imageQuality: 85,
      );
      if (file == null) return;

      final notifier = ref.read(personaControllerProvider.notifier);
      if (isAvatar) {
        await notifier.updateAvatarFile(File(file.path));
      } else {
        await notifier.updateMomentSlotFile(slotIndex, File(file.path));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
