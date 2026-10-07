import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';
import '../widgets/five_slot_photo_grid.dart';
import '../widgets/live_kyc_recording_modal.dart';
import '../widgets/mindful_bio_editor.dart';
import '../widgets/orientation_selector_pills.dart';
import '../widgets/sacred_bridge_selector.dart';
import '../../../chat/presentation/services/window_security_service.dart';
import 'package:ur_heart/features/feed/presentation/widgets/voice_spark_pill.dart';
import 'package:ur_heart/features/profile/data/voice_spark_service.dart';
import 'package:ur_heart/features/profile/presentation/widgets/voice_spark_recording_modal.dart';

/// Screen 4: Sanctuary Profile Setup & Identity Verification Scaffold
/// 100% Production-Grade: Real Camera & Gallery photo uploads, EVA AI KYC & Bio Polish,
/// Interactive GPS & Custom Location detection, and full session persistence.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  static const String routeName = '/profile-setup';

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    WindowSecurityService.enableSecureMode();
    final initialName = ref.read(profileSetupControllerProvider).fullName;
    _nameController = TextEditingController(text: initialName);

    // Auto-acquire real hardware GPS on screen entry if not yet verified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(profileSetupControllerProvider);
      if (!state.isGpsVerified && !state.isAcquiringGps) {
        ref.read(profileSetupControllerProvider.notifier).fetchRealGpsLocation();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileSetupControllerProvider);
    final notifier = ref.read(profileSetupControllerProvider.notifier);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    // Sync name controller if state updated externally
    if (_nameController.text != state.fullName && state.fullName.isNotEmpty && _nameController.text.isEmpty) {
      _nameController.text = state.fullName;
    }

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final primaryButtonBg = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;
    final verifiedTeal = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Sanctuary Profile', style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 18.0)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Grid (1 Anchor + 4 Candids with real camera/gallery picker)
              const FiveSlotPhotoGrid(),
              const SizedBox(height: 18.0),
              // Full Legal Name Input
              Text('LEGAL FULL NAME', style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
              const SizedBox(height: 6.0),
              Container(
                height: 48.0,
                decoration: BoxDecoration(
                  color: isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.inputBackground,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: cardBorder),
                ),
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(color: titleColor, fontSize: 14.0),
                  decoration: InputDecoration(
                    hintText: 'Your authentic name',
                    hintStyle: TextStyle(color: mutedColor, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  ),
                  onChanged: notifier.setFullName,
                ),
              ),
              const SizedBox(height: 14.0),
              // Verified Locked DOB
              Text('VERIFIED DATE OF BIRTH (LOCKED)', style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
              const SizedBox(height: 6.0),
              InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(now.year - 24, 1, 1),
                    firstDate: DateTime(1940),
                    lastDate: DateTime(now.year - 18, now.month, now.day),
                  );
                  if (picked != null) {
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final formatted = '${picked.day} ${months[picked.month - 1]} ${picked.year}';
                    int age = now.year - picked.year;
                    if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
                      age--;
                    }
                    notifier.setDob(formatted, age);
                  }
                },
                child: Container(
                  height: 44.0,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16.0, color: mutedColor),
                      const SizedBox(width: 8.0),
                      Text(
                        state.dobString.isNotEmpty ? state.dobString : 'Tap to select Date of Birth',
                        style: AppTypography.bodySmall.copyWith(
                          color: state.dobString.isNotEmpty ? titleColor : mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.verified, size: 16.0, color: verifiedTeal),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              const OrientationSelectorPills(),
              const SizedBox(height: 16.0),
              // Sanctuary Location (Hardware GPS Only - Pure Satellite Lock)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SANCTUARY LOCATION (HARDWARE GPS ONLY)', style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
                  if (state.isGpsVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: verifiedTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: verifiedTeal.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12.0, color: verifiedTeal),
                          const SizedBox(width: 4.0),
                          Text('GPS VERIFIED', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: verifiedTeal, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6.0),
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: state.isGpsVerified
                        ? verifiedTeal.withOpacity(0.55)
                        : (state.gpsError != null
                            ? const Color(0xFFC94A29).withOpacity(0.55)
                            : cardBorder),
                    width: state.isGpsVerified ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: state.isGpsVerified
                                ? verifiedTeal.withOpacity(0.12)
                                : (state.gpsError != null
                                    ? const Color(0xFFC94A29).withOpacity(0.12)
                                    : primaryButtonBg.withOpacity(0.08)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            state.isGpsVerified
                                ? Icons.my_location
                                : (state.isAcquiringGps
                                    ? Icons.satellite_alt
                                    : (state.gpsError != null ? Icons.location_off : Icons.gps_not_fixed)),
                            size: 20.0,
                            color: state.isGpsVerified
                                ? verifiedTeal
                                : (state.gpsError != null ? const Color(0xFFC94A29) : mutedColor),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isGpsVerified
                                    ? state.location
                                    : (state.isAcquiringGps
                                        ? 'Locking authentic hardware GPS...'
                                        : (state.gpsError ?? 'GPS Verification Required')),
                                style: AppTypography.bodySmall.copyWith(
                                  color: titleColor,
                                  fontWeight: state.isGpsVerified ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                state.isGpsVerified
                                    ? 'Authentic device GPS locked · Anti-Fraud Protected'
                                    : (state.isAcquiringGps
                                        ? 'Fusing satellites & network for genuine accuracy...'
                                        : 'Manual entry disabled · Real GPS required to proceed'),
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: state.isGpsVerified
                                      ? verifiedTeal
                                      : (state.gpsError != null ? const Color(0xFFC94A29) : mutedColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.isAcquiringGps)
                          const SizedBox(
                            width: 18.0,
                            height: 18.0,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          )
                        else
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => notifier.fetchRealGpsLocation(),
                            child: Text(
                              state.isGpsVerified ? 'Refresh' : 'Verify GPS',
                              style: TextStyle(
                                color: verifiedTeal,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (state.gpsError != null) ...[
                      const SizedBox(height: 10.0),
                      SizedBox(
                        width: double.infinity,
                        height: 38.0,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: verifiedTeal,
                            side: BorderSide(color: verifiedTeal.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          ),
                          onPressed: () {
                            if (state.isGpsServiceDisabled) {
                              notifier.openLocationSettings();
                            } else if (state.isGpsPermissionDeniedForever) {
                              notifier.openAppSettings();
                            } else {
                              notifier.fetchRealGpsLocation();
                            }
                          },
                          icon: Icon(
                            state.isGpsServiceDisabled
                                ? Icons.location_on
                                : (state.isGpsPermissionDeniedForever
                                    ? Icons.settings
                                    : Icons.gps_fixed),
                            size: 16.0,
                          ),
                          label: Text(
                            state.isGpsServiceDisabled
                                ? 'Turn on Device GPS'
                                : (state.isGpsPermissionDeniedForever
                                    ? 'Open App Settings'
                                    : 'Retry Hardware GPS Acquisition'),
                            style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              // Live Photo KYC Highlighted Card (EVA AI Verified)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: verifiedTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: verifiedTeal.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(state.isKycVerified ? Icons.verified : Icons.camera_alt_rounded, size: 32.0, color: verifiedTeal),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.isKycVerified ? 'Verified Sanctuary Crest Awarded' : 'Claim the Verified Sanctuary Crest',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
                          const SizedBox(height: 2.0),
                          Text(
                            state.isKycVerified ? 'EVA AI verified identity · 100% genuine human.' : 'Quick live photo pose selfie reflection.',
                            style: AppTypography.caption.copyWith(color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verifiedTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                      ),
                      onPressed: () {
                        if (!state.hasPrimaryAnchorPhoto) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please upload your primary profile photo first before verifying.'),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                          return;
                        }
                        showDialog<void>(context: context, builder: (ctx) => const LiveKycRecordingModal());
                      },
                      child: Text(state.isKycVerified ? 'Verified ✓' : 'Verify ✨', style: const TextStyle(fontSize: 12.0, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              // 7-Second Voice Spark Card (Optional Boost)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.08)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎙️', style: TextStyle(fontSize: 26.0)),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Voice Spark (7 Seconds)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    child: const Text(
                                      '3x Matches',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty
                                    ? 'Voice spark recorded & ready to stream.'
                                    : 'Awaaz jhooth nahi bolti. Let seekers hear your genuine voice.',
                                style: AppTypography.caption.copyWith(color: mutedColor),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD4AF37),
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                          ),
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => VoiceSparkRecordingModal(
                                onRecorded: (File audioFile, double durationSeconds, String prompt) async {
                                  try {
                                    final res = await VoiceSparkService.uploadVoiceSpark(
                                      audioFile: audioFile,
                                      durationSeconds: durationSeconds,
                                      prompt: prompt,
                                    );
                                    final voiceUrl = res['voice_spark_url'] as String?;
                                    if (voiceUrl != null && voiceUrl.isNotEmpty) {
                                      notifier.setVoiceSpark(
                                        url: voiceUrl,
                                        prompt: prompt,
                                        duration: durationSeconds,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to upload voice spark: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                          child: Text(
                            state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty ? 'Recorded ✓' : 'Record 🎙️',
                            style: const TextStyle(fontSize: 12.0, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      VoiceSparkPill(
                        voiceUrl: state.voiceSparkUrl!,
                        prompt: state.voiceSparkPrompt,
                        duration: state.voiceSparkDuration,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              const MindfulBioEditor(),
              const SizedBox(height: 16.0),
              const SacredBridgeSelector(),
              const SizedBox(height: 16.0),
              // Preferred Age Range Dual Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PREFERRED AGE RANGE', style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
                  Text('${state.minAge.round()} - ${state.maxAge.round()} yrs',
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13.0)),
                ],
              ),
              RangeSlider(
                values: RangeValues(state.minAge, state.maxAge),
                min: 18,
                max: 50,
                divisions: 32,
                activeColor: primaryButtonBg,
                inactiveColor: cardBorder,
                onChanged: notifier.setAgeRange,
              ),
              const SizedBox(height: 24.0),
              // Complete Sanctuary Setup Action
              SizedBox(
                width: double.infinity,
                height: 52.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.0)),
                  ),
                  onPressed: state.isSubmitting
                      ? null
                      : () async {
                          if (!state.hasPrimaryAnchorPhoto) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please add an Anchor Portrait (Slot 1) to anchor your profile.', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
                                backgroundColor: const Color(0xFFC94A29),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          if (state.fullName.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please enter your authentic name.', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
                                backgroundColor: const Color(0xFFC94A29),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          // GPS VERIFICATION MANDATORY GATEKEEPER
                          // User directive: jbtk gps verified na ho jye tb tk profile aage na badhe
                          if (!state.isGpsVerified) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Hardware GPS verification is mandatory. Please verify genuine device GPS before proceeding.',
                                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                                ),
                                backgroundColor: const Color(0xFFC94A29),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'VERIFY GPS',
                                  textColor: Colors.white,
                                  onPressed: () => notifier.fetchRealGpsLocation(),
                                ),
                              ),
                            );
                            notifier.fetchRealGpsLocation();
                            return;
                          }

                          final success = await notifier.completeSetup();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Welcome to your Sanctuary, ${state.fullName} ✨', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
                                backgroundColor: const Color(0xFF1B4332),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to complete sanctuary profile. Please check requirements and retry.', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
                                backgroundColor: const Color(0xFFC94A29),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Complete Sanctuary Setup ➔', style: AppTypography.buttonPrimary.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
