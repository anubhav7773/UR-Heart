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
import '../widgets/sacred_photo_veil_card.dart';
import '../../../profile_setup/presentation/widgets/live_kyc_recording_modal.dart';
import 'package:ur_heart/features/feed/presentation/widgets/voice_spark_pill.dart';
import 'package:ur_heart/features/profile/data/voice_spark_service.dart';
import 'package:ur_heart/features/profile/presentation/widgets/voice_spark_recording_modal.dart';

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
              if (state.isInitialLoading && state.profile.isPlaceholder)
                _buildSanctuarySkeleton(isDark)
              else ...[
                PersonaHeaderCard(
                  profile: state.profile,
                  isDark: isDark,
                  onEditAvatar: () =>
                      _showPhotoUploadModal(context, ref, isDark, 0, isAvatar: true),
                  onVerifyKyc: () => _openLivePhotoKycModal(context, ref),
                ),
                SacredPhotoVeilCard(
                  isVeiled: state.profile.isPhotoVeiled,
                  isDark: isDark,
                  onChanged: (val) => notifier.togglePhotoVeil(val),
                ),
                if (state.profile.isLoaded && !state.profile.hasVerifiedCrest)
                  _buildSanctuaryKycPromptCard(context, ref, isDark),
                MomentsMediaGrid(
                  photos: state.profile.momentPhotos,
                  isDark: isDark,
                  onReplaceSlot: (slot) =>
                      _showPhotoUploadModal(context, ref, isDark, slot, isAvatar: false),
                ),
                _buildVoiceSparkCard(context, ref, state, isDark),
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
              ],
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
    final persona = ref.read(personaControllerProvider).profile;
    final List<String> profileUrls = [];
    if (persona.avatarUrl.trim().isNotEmpty) {
      profileUrls.add(persona.avatarUrl.trim());
    }
    for (final m in persona.momentPhotos) {
      if (m.trim().isNotEmpty && !profileUrls.contains(m.trim())) {
        profileUrls.add(m.trim());
      }
    }

    if (profileUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your profile photos first before verifying KYC.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveKycRecordingModal(
        anchorPhotoBase64: '',
        profilePhotoUrls: profileUrls,
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

  Widget _buildSanctuarySkeleton(bool isDark) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final shimmerBase = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Card Skeleton
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: shimmerBase,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 140,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 100,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 70,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Crest / Banner Skeleton
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 90,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark
                    ? DarkSanctuaryTokens.primaryCoral
                    : LightSanctuaryTokens.terracottaAccent,
              ),
            ),
          ),
        ),
        // Moments Grid Skeleton
        Container(
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
              Container(
                height: 18,
                width: 160,
                decoration: BoxDecoration(
                  color: shimmerBase,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: List.generate(
                  4,
                  (index) => Container(
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openVoiceSparkRecordingModal(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceSparkRecordingModal(
        onRecorded: (File audioFile, double durationSeconds, String prompt) async {
          final notifier = ref.read(personaControllerProvider.notifier);
          try {
            final res = await VoiceSparkService.uploadVoiceSpark(
              audioFile: audioFile,
              durationSeconds: durationSeconds,
              prompt: prompt,
            );
            final voiceUrl = res['voice_spark_url'] as String?;
            if (voiceUrl != null && voiceUrl.isNotEmpty) {
              await notifier.updateVoiceSpark(
                voiceSparkUrl: voiceUrl,
                voiceSparkPrompt: prompt,
                voiceSparkDuration: durationSeconds,
                isVoiceVerified: true,
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save Voice Spark: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildVoiceSparkCard(
    BuildContext context,
    WidgetRef ref,
    PersonaState state,
    bool isDark,
  ) {
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final cardBg = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final textHeadline = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final textMuted = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final hasVoice = state.profile.voiceSparkUrl != null && state.profile.voiceSparkUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasVoice ? gold.withValues(alpha: 0.35) : cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.15),
                  border: Border.all(color: gold.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('🎙️', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Voice Spark',
                          style: AppTypography.titleH2.copyWith(
                            fontSize: 16,
                            color: textHeadline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasVoice)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'Verified Authentic',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '7-Second Audio Note · Awaaz Jhooth Nahi Bolti',
                      style: AppTypography.caption.copyWith(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasVoice) ...[
            VoiceSparkPill(
              voiceUrl: state.profile.voiceSparkUrl!,
              prompt: state.profile.voiceSparkPrompt,
              duration: state.profile.voiceSparkDuration,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openVoiceSparkRecordingModal(context, ref, isDark),
                  icon: Icon(Icons.refresh_rounded, size: 16, color: gold),
                  label: Text(
                    'Re-record',
                    style: TextStyle(
                      color: gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Remove Voice Spark?', style: TextStyle(color: textHeadline)),
                        content: Text(
                          'Your profile will no longer feature the 7-second audio note.',
                          style: TextStyle(color: textMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(true),
                            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await VoiceSparkService.deleteVoiceSpark();
                      await ref.read(personaControllerProvider.notifier).deleteVoiceSpark();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Profiles with an authentic 7-second voice spark get 3x more meaningful connections. Let your voice express what photos cannot capture.',
              style: AppTypography.bodySmall.copyWith(
                color: textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _openVoiceSparkRecordingModal(context, ref, isDark),
                icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Record 7-Second Voice Spark',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E3A2F) : const Color(0xFF152A20),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: gold.withValues(alpha: 0.4), width: 1.2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
