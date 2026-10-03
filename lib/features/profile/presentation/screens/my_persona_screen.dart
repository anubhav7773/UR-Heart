import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/persona_controller.dart';
import '../widgets/locked_credentials_card.dart';
import '../widgets/moments_media_grid.dart';
import '../widgets/persona_header_card.dart';
import '../widgets/persona_tabs_header.dart';
import '../widgets/photo_adjuster_dialog.dart';
import '../widgets/preferences_slider_card.dart';
import '../../../profile_setup/presentation/widgets/live_kyc_recording_modal.dart';

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
                onVerifyKyc: () => _openLivePhotoKycModal(context, ref),
              ),
              if (!state.profile.hasVerifiedCrest)
                _buildSanctuaryKycPromptCard(context, ref, isDark),
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
    final profile = ref.read(personaControllerProvider).profile;
    final String currentPhoto = isAvatar
        ? profile.avatarUrl
        : (slotIndex >= 0 && slotIndex < profile.momentPhotos.length
            ? profile.momentPhotos[slotIndex]
            : '');
    final bool hasExistingPhoto = currentPhoto.isNotEmpty;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAvatar
                    ? 'Sanctuary Avatar'
                    : 'Sacred Moment #${slotIndex + 1}',
                style: AppTypography.titleH2.copyWith(
                  fontSize: 18,
                  color: isDark
                      ? DarkSanctuaryTokens.textHeadline
                      : LightSanctuaryTokens.textHeadline,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Adjust framing, pan & zoom so your face displays clearly.',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark
                      ? DarkSanctuaryTokens.textMuted
                      : LightSanctuaryTokens.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Option 1: Adjust Existing Photo (if present)
              if (hasExistingPhoto) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.crop_rotate_rounded, color: gold, size: 20),
                  ),
                  title: const Text('Adjust / Reframe Current Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pan, zoom, & center so it is clean & visible'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _adjustExistingPhoto(
                      context,
                      ref,
                      currentPhoto,
                      isDark,
                      isAvatar: isAvatar,
                      slotIndex: slotIndex,
                    );
                  },
                ),
                const Divider(height: 8),
              ],

              // Option 2: Camera Capture
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: Text(hasExistingPhoto ? 'Replace with Camera' : 'Capture with Camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndProcessPhoto(
                    context,
                    ref,
                    ImageSource.camera,
                    isDark: isDark,
                    isAvatar: isAvatar,
                    slotIndex: slotIndex,
                  );
                },
              ),

              // Option 3: Gallery Select
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(hasExistingPhoto ? 'Replace from Gallery' : 'Select from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndProcessPhoto(
                    context,
                    ref,
                    ImageSource.gallery,
                    isDark: isDark,
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

  Future<void> _adjustExistingPhoto(
    BuildContext context,
    WidgetRef ref,
    String photoPathOrUrl,
    bool isDark, {
    required bool isAvatar,
    int slotIndex = 0,
  }) async {
    try {
      File fileToAdjust;
      if (photoPathOrUrl.startsWith('http://') || photoPathOrUrl.startsWith('https://')) {
        // Download remote photo to temporary storage for lossless adjustment
        final tempDir = Directory.systemTemp;
        final tempPath = '${tempDir.path}/existing_slot_${slotIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final response = await http.get(Uri.parse(photoPathOrUrl));
        if (response.statusCode != 200) {
          throw Exception('Unable to fetch image from network (HTTP ${response.statusCode})');
        }
        fileToAdjust = File(tempPath);
        await fileToAdjust.writeAsBytes(response.bodyBytes);
      } else {
        fileToAdjust = File(photoPathOrUrl);
        if (!fileToAdjust.existsSync()) {
          throw Exception('Local photo file not found at path');
        }
      }

      if (!context.mounted) return;
      final adjustedFile = await SanctuaryPhotoAdjusterDialog.show(
        context,
        file: fileToAdjust,
        isDark: isDark,
        isAvatar: isAvatar,
        targetAspectRatio: 1.0,
      );
      if (adjustedFile == null) return; // User cancelled

      final notifier = ref.read(personaControllerProvider.notifier);
      if (isAvatar) {
        await notifier.updateAvatarFile(adjustedFile);
      } else {
        await notifier.updateMomentSlotFile(slotIndex, adjustedFile);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not adjust photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickAndProcessPhoto(
    BuildContext context,
    WidgetRef ref,
    ImageSource source, {
    required bool isDark,
    required bool isAvatar,
    int slotIndex = 0,
  }) async {
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1800,
        imageQuality: 90,
      );
      if (file == null) return;

      if (!context.mounted) return;
      if (kIsWeb) {
        // On Web, directly upload without modal disk temp operations
        final notifier = ref.read(personaControllerProvider.notifier);
        if (isAvatar) {
          await notifier.updateAvatarFile(File(file.path));
        } else {
          await notifier.updateMomentSlotFile(slotIndex, File(file.path));
        }
        return;
      }

      // Allow user to interactively pan, zoom, rotate, and frame the photo
      final adjustedFile = await SanctuaryPhotoAdjusterDialog.show(
        context,
        file: File(file.path),
        isDark: isDark,
        isAvatar: isAvatar,
        targetAspectRatio: 1.0,
      );
      if (adjustedFile == null) return; // User cancelled adjustment

      final notifier = ref.read(personaControllerProvider.notifier);
      if (isAvatar) {
        await notifier.updateAvatarFile(adjustedFile);
      } else {
        await notifier.updateMomentSlotFile(slotIndex, adjustedFile);
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

  void _openLivePhotoKycModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveKycRecordingModal(
        anchorPhotoBase64: '',
        onKycCompleted: (bool isVerified, String message) {
          if (isVerified) {
            ref.read(personaControllerProvider.notifier).onKycVerified();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSanctuaryKycPromptCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final coral = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: coral.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: coral.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: coral.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_user_outlined, color: coral, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim Verified Sanctuary Crest 🛡️',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: headlineColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prove genuine human presence to unlock 2x discovery resonance.',
                      style: AppTypography.caption.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: coral,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text(
                'Begin Live Photo Reflection ✨',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _openLivePhotoKycModal(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
