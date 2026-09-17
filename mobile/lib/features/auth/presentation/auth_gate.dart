import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/features/auth/data/profile_repository.dart';
import 'package:ur_heart/features/auth/presentation/onboarding_screen.dart';
import 'package:ur_heart/features/auth/presentation/profile_setup_screen.dart';
import 'package:ur_heart/features/home/presentation/main_shell_screen.dart';
import 'package:ur_heart/features/kyc/presentation/photo_upload_screen.dart';

/// Root Navigation Gatekeeper implementing a linear, non-skippable onboarding state machine.
class AuthGate extends StatelessWidget {
  final Stream<User?>? authStream;

  const AuthGate({super.key, this.authStream});

  Stream<User?> _resolveStream() {
    if (authStream != null) return authStream!;
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _resolveStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingSplash();
        }

        final User? user = snapshot.data;
        if (user == null) {
          return const OnboardingScreen();
        }

        return _AuthSessionChecker(firebaseUser: user);
      },
    );
  }
}

class _AuthSessionChecker extends StatefulWidget {
  final User firebaseUser;

  const _AuthSessionChecker({required this.firebaseUser});

  @override
  State<_AuthSessionChecker> createState() => _AuthSessionCheckerState();
}

class _AuthSessionCheckerState extends State<_AuthSessionChecker> {
  final ProfileRepository _profileRepo = ProfileRepository();
  bool _isLoading = true;
  Widget? _destinationScreen;

  @override
  void initState() {
    super.initState();
    _evaluateUserState();
  }

  @override
  void didUpdateWidget(covariant _AuthSessionChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser.uid != widget.firebaseUser.uid) {
      _evaluateUserState();
    }
  }

  Future<void> _evaluateUserState() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _profileRepo.fetchUserProfile();

      if (!mounted) return;

      if (profile == null) {
        // Case 1: Profile missing in DB (404) -> strictly ProfileSetupScreen
        setState(() {
          _destinationScreen = const ProfileSetupScreen();
          _isLoading = false;
        });
        return;
      }

      final String fullName = (profile['full_name'] ?? '').toString().trim();
      final String city = (profile['city'] ?? '').toString().trim();
      final bool isProfileComplete = fullName.isNotEmpty &&
          fullName.toLowerCase() != 'ur heart user' &&
          city.isNotEmpty;

      if (!isProfileComplete) {
        // Case 1: Incomplete profile -> ProfileSetupScreen
        setState(() {
          _destinationScreen = const ProfileSetupScreen();
          _isLoading = false;
        });
        return;
      }

      final int photoCount = (profile['photo_count'] as num?)?.toInt() ?? 0;
      final String kycState = (profile['kyc_state'] ?? 'pending_ai').toString();
      final bool kycStatus = profile['kyc_status'] == true;

      // Case 2: Profile exists, but photos not uploaded or KYC unsubmitted
      if (photoCount < 1 || (kycState == 'pending_ai' && !kycStatus)) {
        setState(() {
          _destinationScreen = const PhotoUploadScreen();
          _isLoading = false;
        });
        return;
      }

      // Case 3: Profile complete AND KYC submitted/verified -> Discovery Feed
      setState(() {
        _destinationScreen = const MainShellScreen();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("AuthGate evaluation error: $e");
      if (mounted) {
        // Fallback safely to ProfileSetupScreen so user is never stuck
        setState(() {
          _destinationScreen = const ProfileSetupScreen();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _destinationScreen == null) {
      return const _AuthLoadingSplash();
    }
    return _destinationScreen!;
  }
}

/// Loading splash screen with dark canvas and pulsating heart animation
class _AuthLoadingSplash extends StatefulWidget {
  const _AuthLoadingSplash();

  @override
  State<_AuthLoadingSplash> createState() => _AuthLoadingSplashState();
}

class _AuthLoadingSplashState extends State<_AuthLoadingSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color brandPrimary = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF16161D),
                  boxShadow: [
                    BoxShadow(
                      color: brandPrimary.withValues(alpha: 0.4),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: brandPrimary,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "UR-Heart",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Securing your session...",
              style: TextStyle(
                color: Color(0xFFA0A0B2),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
