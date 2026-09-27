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

/// Screen 4: Sanctuary Profile Setup & Identity Verification Scaffold
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  static const String routeName = '/profile-setup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSetupControllerProvider);
    final notifier = ref.read(profileSetupControllerProvider.notifier);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

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
        title: Text('Sanctuary Profile', style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 18.0)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Grid (1 Anchor + 4 Candids)
              FiveSlotPhotoGrid(
                onSelectImage: (slotNumber) async {
                  // Create a minimal local file to simulate selection
                  final tempFile = File('${Directory.systemTemp.path}/slot_${slotNumber}_sample.jpg');
                  if (!tempFile.existsSync()) {
                    await tempFile.writeAsBytes(List.filled(2000, 255));
                  }
                  await notifier.processAndUploadPhoto(slotNumber: slotNumber, rawFile: tempFile);
                },
              ),
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
              Container(
                height: 44.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16.0, color: mutedColor),
                    const SizedBox(width: 8.0),
                    Text(state.dobString, style: AppTypography.bodySmall.copyWith(color: titleColor, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.verified, size: 16.0, color: verifiedTeal),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              const OrientationSelectorPills(),
              const SizedBox(height: 16.0),
              // Sanctuary Location with GPS Update
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SANCTUARY LOCATION', style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
                  TextButton.icon(
                    onPressed: () => notifier.updateLocation('Bandra West, Mumbai (GPS Verified)'),
                    icon: Icon(Icons.my_location, size: 13.0, color: verifiedTeal),
                    label: Text('Update Via GPS', style: TextStyle(color: verifiedTeal, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Container(
                height: 44.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: cardBorder)),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16.0, color: mutedColor),
                    const SizedBox(width: 8.0),
                    Text(state.location, style: AppTypography.bodySmall.copyWith(color: titleColor)),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              // Live Video KYC Highlighted Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: verifiedTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: verifiedTeal.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(state.isKycVerified ? Icons.verified : Icons.videocam, size: 32.0, color: verifiedTeal),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.isKycVerified ? 'Verified Sanctuary Crest Awarded' : 'Claim the Verified Sanctuary Crest',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor)),
                          const SizedBox(height: 2.0),
                          Text(
                            state.isKycVerified ? 'Groq LPU verified identity · 100% genuine human.' : 'Gentle 3-second live selfie video reflection.',
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
                        showDialog<void>(context: context, builder: (ctx) => const LiveKycRecordingModal());
                      },
                      child: Text(state.isKycVerified ? 'Verified ✓' : 'Verify ✨', style: const TextStyle(fontSize: 12.0, color: Colors.white)),
                    ),
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
                  style: ElevatedButton.styleFrom(backgroundColor: primaryButtonBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.0))),
                  onPressed: () async {
                    await notifier.completeSetup();
                    if (context.mounted) {
                      Navigator.of(context).pushNamed('/feed');
                    }
                  },
                  child: Text('Complete Sanctuary Setup ➔', style: AppTypography.buttonPrimary.copyWith(color: Colors.white)),
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
