import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';

/// Screen 1: Splash, Google One-Tap & Neutral Age-Gate Screen
/// Spec: URH-UIX-009 Section 3 Screen 1
class OnboardingScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onGoogleAuthSuccess;

  const OnboardingScreen({
    super.key,
    this.lang = 'en',
    this.onGoogleAuthSuccess,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  DateTime? _selectedDob;

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  Future<void> _selectDateOfBirth() async {
    final DateTime now = DateTime.now();
    // Default initial neutral date: 18 years ago
    final DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: URHeartTheme.darkTheme.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: URHeartColors.brandPrimary,
              surface: URHeartColors.cardSurface,
              onSurface: URHeartColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Glowing Neon Heart Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: URHeartColors.cardSurface,
                    boxShadow: [
                      BoxShadow(
                        color: URHeartColors.brandPrimary.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: URHeartColors.brandPrimary,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'UR-Heart',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: URHeartColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '100% Free Desi Dating\nमुफ़्त और सुरक्षित मेल-जोल',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: URHeartColors.textSecondary,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const Spacer(),

              // Center Neutral Age-Gate Card
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: URHeartColors.cardSurface,
                  borderRadius: URHeartTheme.radiusCard,
                  border: Border.all(color: URHeartColors.surfaceRaised, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: URHeartColors.accentGold.withOpacity(0.15),
                            borderRadius: URHeartTheme.radiusPill,
                            border: Border.all(color: URHeartColors.accentGold, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_rounded, color: URHeartColors.accentGold, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _t('ageGateNotice'),
                                style: const TextStyle(
                                  color: URHeartColors.accentGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectDateOfBirth,
                      borderRadius: URHeartTheme.radiusInput,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: URHeartColors.surfaceRaised,
                          borderRadius: URHeartTheme.radiusInput,
                          border: Border.all(
                            color: _selectedDob == null
                                ? URHeartColors.surfaceRaised
                                : URHeartColors.brandSecondary,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDob == null
                                  ? 'Select Date of Birth / जन्मतिथि'
                                  : '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}',
                              style: TextStyle(
                                color: _selectedDob == null
                                    ? URHeartColors.textMuted
                                    : URHeartColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(Icons.calendar_month_rounded, color: URHeartColors.brandSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('ageGateSubtext'),
                      style: const TextStyle(color: URHeartColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Primary CTA: Google One-Tap
              SizedBox(
                height: URHeartTheme.minTouchTarget,
                child: ElevatedButton.icon(
                  onPressed: widget.onGoogleAuthSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: const RoundedRectangleBorder(borderRadius: URHeartTheme.radiusPill),
                  ),
                  icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 28),
                  label: Text(
                    _t('btnGoogleAuth'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary: Phone Number
              SizedBox(
                height: URHeartTheme.minTouchTarget,
                child: OutlinedButton(
                  onPressed: () {},
                  child: Text(
                    _t('btnPhoneAuth'),
                    style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Legal Footer
              Text(
                _t('legalFooter'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: URHeartColors.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
