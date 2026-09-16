import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import '../../home/presentation/main_shell_screen.dart';
import '../../kyc/presentation/photo_upload_screen.dart';
import '../data/auth_repository.dart';

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
  bool _isGoogleLoading = false;
  final AuthRepository _authRepository = AuthRepository();

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  bool _isAdult(DateTime? dob) {
    if (dob == null) return false;
    final DateTime now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

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

  Future<void> _handleGoogleSignIn() async {
    if (!_isAdult(_selectedDob)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strictly 18+ years only. Please select birth date.'),
          backgroundColor: URHeartColors.statusDanger,
        ),
      );
      return;
    }

    setState(() => _isGoogleLoading = true);
    try {
      final userCredential = await _authRepository.signInWithGoogle();
      if (userCredential != null) {
        await _authRepository.syncSessionWithBackend(dob: _selectedDob!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to UR-Heart! / स्वागत है!'),
              backgroundColor: URHeartColors.statusSuccess,
            ),
          );
          if (widget.onGoogleAuthSuccess != null) {
            widget.onGoogleAuthSuccess!();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PhotoUploadScreen(
                  lang: widget.lang,
                  onContinue: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => MainShellScreen(lang: widget.lang),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login Failed: ${e.toString()}'),
            backgroundColor: URHeartColors.statusDanger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _openEmailAuthBottomSheet() {
    if (!_isAdult(_selectedDob)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strictly 18+ years only. Please select birth date.'),
          backgroundColor: URHeartColors.statusDanger,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmailAuthBottomSheet(
        dob: _selectedDob!,
        lang: widget.lang,
        authRepository: _authRepository,
        onSuccess: widget.onGoogleAuthSuccess,
      ),
    );
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
                        color: URHeartColors.brandPrimary.withValues(alpha: 0.35),
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
                            color: URHeartColors.accentGold.withValues(alpha: 0.15),
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
                                : (_isAdult(_selectedDob)
                                    ? URHeartColors.brandSecondary
                                    : URHeartColors.statusDanger),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDob == null
                                  ? 'Select Date of Birth / जन्मतिथि'
                                  : '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year} (${_isAdult(_selectedDob) ? "18+ Eligible" : "Under 18"})',
                              style: TextStyle(
                                color: _selectedDob == null
                                    ? URHeartColors.textMuted
                                    : (_isAdult(_selectedDob)
                                        ? URHeartColors.textPrimary
                                        : URHeartColors.statusDanger),
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
                  onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: const RoundedRectangleBorder(borderRadius: URHeartTheme.radiusPill),
                  ),
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                        )
                      : const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 28),
                  label: Text(
                    _isGoogleLoading ? 'Connecting...' : _t('btnGoogleAuth'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary: Email & Password
              SizedBox(
                height: URHeartTheme.minTouchTarget,
                child: OutlinedButton(
                  onPressed: _openEmailAuthBottomSheet,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: URHeartColors.surfaceRaised, width: 1.5),
                    shape: const RoundedRectangleBorder(borderRadius: URHeartTheme.radiusPill),
                  ),
                  child: Text(
                    _t('btnEmailAuth'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: URHeartColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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

/// Bottom sheet supporting both Sign In and Sign Up with Email and Password
class _EmailAuthBottomSheet extends StatefulWidget {
  final DateTime dob;
  final String lang;
  final AuthRepository authRepository;
  final VoidCallback? onSuccess;

  const _EmailAuthBottomSheet({
    required this.dob,
    required this.lang,
    required this.authRepository,
    this.onSuccess,
  });

  @override
  State<_EmailAuthBottomSheet> createState() => _EmailAuthBottomSheetState();
}

class _EmailAuthBottomSheetState extends State<_EmailAuthBottomSheet> {
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: URHeartColors.statusDanger,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          backgroundColor: URHeartColors.statusDanger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await widget.authRepository.signUpWithEmail(email, password);
      } else {
        await widget.authRepository.signInWithEmail(email, password);
      }

      // Sync user session with backend
      await widget.authRepository.syncSessionWithBackend(dob: widget.dob);

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignUp
                ? 'Account created successfully! / खाता सफलतापूर्वक बनाया गया!'
                : 'Welcome back to UR-Heart! / स्वागत है!'),
            backgroundColor: URHeartColors.statusSuccess,
          ),
        );
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PhotoUploadScreen(
                lang: widget.lang,
                onContinue: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => MainShellScreen(lang: widget.lang),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: URHeartColors.statusDanger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16161D), // #16161D
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: URHeartColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Toggle Tabs: Sign In / Sign Up
            Container(
              decoration: const BoxDecoration(
                color: URHeartColors.surfaceRaised,
                borderRadius: URHeartTheme.radiusPill,
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSignUp = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isSignUp ? URHeartColors.brandPrimary : Colors.transparent,
                          borderRadius: URHeartTheme.radiusPill,
                        ),
                        child: Text(
                          'Sign In / लॉगिन',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_isSignUp ? Colors.white : URHeartColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSignUp = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSignUp ? URHeartColors.brandPrimary : Colors.transparent,
                          borderRadius: URHeartTheme.radiusPill,
                        ),
                        child: Text(
                          'Sign Up / नया खाता',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isSignUp ? Colors.white : URHeartColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Email Field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Email Address / ईमेल पता',
                hintStyle: TextStyle(color: URHeartColors.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.email_outlined, color: URHeartColors.brandSecondary, size: 20),
                filled: true,
                fillColor: URHeartColors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: URHeartTheme.radiusInput,
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 14),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Password / पासवर्ड (कम से कम 6 अक्षर)',
                hintStyle: const TextStyle(color: URHeartColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: URHeartColors.brandSecondary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: URHeartColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: URHeartColors.surfaceRaised,
                border: const OutlineInputBorder(
                  borderRadius: URHeartTheme.radiusInput,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Action Button: Electric Crimson Pill (#FF2E63)
            SizedBox(
              height: URHeartTheme.minTouchTarget,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E63), // #FF2E63
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: URHeartTheme.radiusPill),
                  elevation: 4,
                  shadowColor: const Color(0xFFFF2E63).withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isSignUp ? 'Create Account & Continue' : 'Sign In & Continue',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
