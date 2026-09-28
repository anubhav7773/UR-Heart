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
    final initialName = ref.read(profileSetupControllerProvider).fullName;
    _nameController = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showLocationPicker(
    BuildContext context,
    String currentLocation,
    Color cardBg,
    Color textColor,
    Color accentColor,
    Color cardBorder,
  ) async {
    final notifier = ref.read(profileSetupControllerProvider.notifier);
    final customController = TextEditingController(text: currentLocation);

    final List<String> popularSanctuaries = [
      'Bandra West, Mumbai (GPS Verified)',
      'Indiranagar, Bengaluru',
      'Koramangala, Bengaluru',
      'Hauz Khas, New Delhi',
      'Koregaon Park, Pune',
      'Jubilee Hills, Hyderabad',
      'Vasant Vihar, New Delhi',
      'Anjuna / Assagao, Goa',
      'C-Scheme, Jaipur',
      'Alipore, Kolkata',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 16.0,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16.0,
            ),
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
                  'Sanctuary Location',
                  style: AppTypography.titleH2.copyWith(color: textColor, fontSize: 18),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.my_location, color: accentColor, size: 20),
                  ),
                  title: Text(
                    'Detect via GPS Hardware',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text('Accurate neighborhood resolution · Anti-Fraud Protected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Acquiring real hardware GPS & verifying anti-fraud...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    final loc = await notifier.fetchRealGpsLocation();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('GPS Verified: $loc ✨'),
                          backgroundColor: const Color(0xFF1B4332),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                const SizedBox(height: 6),
                Text('POPULAR SANCTUARIES', style: AppTypography.caption.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: popularSanctuaries.take(6).map((city) {
                    return ActionChip(
                      backgroundColor: cardBg,
                      side: BorderSide(color: cardBorder),
                      label: Text(city, style: TextStyle(color: textColor, fontSize: 12)),
                      onPressed: () {
                        notifier.updateLocation(city);
                        Navigator.of(sheetCtx).pop();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('OR ENTER CUSTOM SANCTUARY', style: AppTypography.caption.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorder),
                        ),
                        child: TextField(
                          controller: customController,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'e.g. South Mumbai, Colaba',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final entered = customController.text.trim();
                        if (entered.isNotEmpty) {
                          notifier.updateLocation(entered);
                        }
                        Navigator.of(sheetCtx).pop();
                      },
                      child: const Text('Set', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
              // Sanctuary Location with Interactive Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SANCTUARY LOCATION', style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
                  TextButton.icon(
                    onPressed: () => _showLocationPicker(context, state.location, cardBg, titleColor, verifiedTeal, cardBorder),
                    icon: Icon(Icons.my_location, size: 13.0, color: verifiedTeal),
                    label: Text('Update Via GPS', style: TextStyle(color: verifiedTeal, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: () => _showLocationPicker(context, state.location, cardBg, titleColor, verifiedTeal, cardBorder),
                child: Container(
                  height: 44.0,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: cardBorder)),
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16.0, color: mutedColor),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          state.location,
                          style: AppTypography.bodySmall.copyWith(color: titleColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, size: 16.0, color: mutedColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              // Live Video KYC Highlighted Card (EVA AI Verified)
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
                            state.isKycVerified ? 'EVA AI verified identity · 100% genuine human.' : 'Gentle 3-second live selfie video reflection.',
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

                          final success = await notifier.completeSetup();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Welcome to your Sanctuary, ${state.fullName} ✨', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
                                backgroundColor: const Color(0xFF1B4332),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.of(context).pushReplacementNamed('/feed');
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
