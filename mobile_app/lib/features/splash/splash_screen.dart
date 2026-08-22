import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/security_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../home/home_screen.dart';
import '../profile/onboarding_screen.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Entrance Animations
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. Ambient Breathing Animation (2-second periodic easeInOut cycle)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _breathingAnimation = Tween<double>(begin: 2.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward();
    _breathingController.repeat(reverse: true);

    WindowSecurityService.syncFromStorage();
    _checkAuthStateAndNavigate();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathingController.dispose();
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

      if (currentUser != null || (token != null && token.isNotEmpty)) {
        if (isComplete) {
          // 1. Check for pending notification deep links from cold start
          final initialMsg = NotificationRouter.pendingNotification ??
              await FirebaseMessaging.instance.getInitialMessage();

          // 2. Navigate to MainHomeScreen first (so Home/Feed sits underneath in the stack)
          _navigateTo(const MainHomeScreen());

          // 3. If launched from notification, push ChatScreen on top once Home is mounted
          if (initialMsg != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NotificationRouter.handleNotificationClick(initialMsg);
            });
          }
          return;
        } else {
          _navigateTo(const OnboardingScreen());
          return;
        }
      } else {
        _navigateTo(const AuthScreen());
      }
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
      backgroundColor: AppTheme.surface_root,
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
                    Color(0x22FF3366),
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
                // Animated Pulsing Heart Icon with Breathing Ambient Glow
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _breathingAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF3366),
                              Color(0xFFE02856),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x55FF3366),
                              blurRadius: 32.0,
                              spreadRadius: _breathingAnimation.value,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Fade-in App Name & Clean Single-Line Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF3366), Color(0xFFFF5E7E)],
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
                      const SizedBox(height: 12),
                      const Text(
                        'Genuine Connections Across Bharat',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.text_secondary,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Pinned Hardware Trust Watermark
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: AppTheme.text_tertiary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Protected by Hardware-Level Privacy',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.text_tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
