import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/security_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/auth_screen.dart';
import '../home/home_screen.dart';
import '../profile/onboarding_screen.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward();
    WindowSecurityService.syncFromStorage();
    _checkAuthStateAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasNavigated = false;

  Future<void> _checkAuthStateAndNavigate() async {
    // 3-Second Maximum Timeout Safeguard
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && !_hasNavigated) {
        _navigateTo(const AuthScreen());
      }
    });

    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted || _hasNavigated) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final token = await StorageManager.instance.getAuthToken();
      final isComplete = await StorageManager.instance.isProfileComplete();

      if (!mounted || _hasNavigated) return;

      Widget targetScreen;
      if (currentUser != null || (token != null && token.isNotEmpty)) {
        if (isComplete) {
          targetScreen = const MainHomeScreen();
        } else {
          targetScreen = const OnboardingScreen();
        }
      } else {
        targetScreen = const AuthScreen();
      }

      _navigateTo(targetScreen);
    } catch (_) {
      if (mounted && !_hasNavigated) {
        _navigateTo(const AuthScreen());
      }
    }
  }

  void _navigateTo(Widget targetScreen) {
    if (!mounted || _hasNavigated) return;
    setState(() => _hasNavigated = true);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Color(0x33E91E63),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Pulsing Heart Icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: const AppLogo(size: 100, showGlow: true),
                ),
                const SizedBox(height: 32),

                // Fade-in App Name & Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFFF4081)],
                        ).createShader(bounds),
                        child: const Text(
                          'UR Heart',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Connect Hearts • Genuine Connections Across Rural & Urban',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Genuine Connections Across Rural & Bharat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Loading Indicator
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Secured by End-to-End Encryption',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
