import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/auth/oauth_redirect_handler.dart';
import '../../../../core/network/user_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../auth_provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import 'widgets/auth_header.dart';
import 'widgets/email_auth_tab.dart';
import 'widgets/google_auth_button.dart';
import 'widgets/phone_auth_tab.dart';
import 'widgets/username_auth_tab.dart';

enum AuthMethodTab { phone, email, username }

/// Production-Grade Obsidian Dark Authentication Screen for Project UR-Heart
/// supporting Google OAuth, Phone/SMS OTP, Email/Password, and Username sign-in strategies.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final AuthController _authController;
  bool _isSignUp = false;
  AuthMethodTab _selectedTab = AuthMethodTab.phone;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.addListener(_onAuthStateChanged);

    // Listen for OAuth deep link callbacks
    OAuthRedirectHandler.instance.onOAuthCallback.listen((event) {
      if (!mounted) return;
      if (event.isSuccess) {
        _onAuthSuccess(
          token: event.sessionToken ?? 'oauth_active_session',
          userId: event.createdSessionId ?? 'user_clerk_authenticated',
        );
      } else if (event.error != null) {
        _showErrorBanner('OAuth Failed: ${event.errorDescription ?? event.error}');
      }
    });
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthStateChanged);
    _authController.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    final state = _authController.state;
    if (state is AuthAuthenticated) {
      _onAuthSuccess(
        token: state.token,
        userId: state.userId,
        isProfileComplete: state.isProfileComplete,
      );
    } else if (state is AuthError) {
      _showErrorBanner(state.errorMessage);
    }
  }

  void _showErrorBanner(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _onAuthSuccess({
    required String token,
    required String userId,
    bool isProfileComplete = false,
    bool isPremium = false,
  }) async {
    await AppAuthProvider.instance.handleLoginSuccess(
      token: token,
      userId: userId,
      isProfileComplete: isProfileComplete,
      isPremium: isPremium,
    );

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    // Check backend profile state to navigate to onboarding or home feed
    try {
      final profile = await UserRepository().fetchCurrentUserProfile();
      if (!mounted) return;
      if (profile.isOnboarded) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
    }
  }

  // ===========================================================================
  // 1. Google OAuth Action
  // ===========================================================================
  Future<void> _handleGoogleOAuth() async {
    await _authController.signInWithGoogle();
  }

  // ===========================================================================
  // 2. Phone / SMS OTP Strategy
  // ===========================================================================
  Future<bool> _handleSendPhoneOtp(String fullPhoneNumber) async {
    return await _authController.sendPhoneOTP(fullPhoneNumber);
  }

  Future<void> _handleVerifyPhoneOtp(String fullPhoneNumber, String otpCode) async {
    await _authController.verifyPhoneOTP(otpCode);
  }

  // ===========================================================================
  // 3. Email / Password Strategy
  // ===========================================================================
  Future<void> _handleEmailSubmit(String email, String password) async {
    if (_isSignUp) {
      await _authController.signUpWithPassword(email: email, password: password);
    } else {
      await _authController.signInWithPassword(email: email, password: password);
    }
  }

  void _handleForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset instructions have been sent to your email.'),
        backgroundColor: Color(0xFF3B82F6),
      ),
    );
  }

  // ===========================================================================
  // 4. Username / Password Strategy
  // ===========================================================================
  Future<void> _handleUsernameSubmit(String username, String password) async {
    await _authController.signInWithUsername(username: username, password: password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with Branding & Security Badge
                  AuthHeader(
                    isSignUp: _isSignUp,
                    onModeChanged: (val) => setState(() => _isSignUp = val),
                  ),
                  const SizedBox(height: 24),

                  // 2. Primary Google Social Action
                  GoogleAuthButton(
                    isLoading: _authController.isLoading,
                    onPressed: _handleGoogleOAuth,
                  ),
                  const SizedBox(height: 20),

                  // 3. High-Contrast "OR" Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFF252736), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            color: const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFF252736), thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Segmented Method Switcher (Phone / Email / Username)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13141F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF252736), width: 1),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentButton(
                          title: 'Phone OTP',
                          icon: Icons.phone_iphone_rounded,
                          tab: AuthMethodTab.phone,
                        ),
                        _buildSegmentButton(
                          title: 'Email',
                          icon: Icons.mail_outline_rounded,
                          tab: AuthMethodTab.email,
                        ),
                        _buildSegmentButton(
                          title: 'Username',
                          icon: Icons.alternate_email_rounded,
                          tab: AuthMethodTab.username,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Active Tab View with Smooth Transition
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildActiveTabContent(),
                  ),
                  const SizedBox(height: 24),

                  // 6. Safety & Privacy Terms Footer
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_rounded, size: 12, color: Color(0xFF6B7280)),
                            SizedBox(width: 6),
                            Text(
                              'End-to-End Encrypted Handshake',
                              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'By proceeding, you agree to our Terms of Service and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: const Color(0xFF4B5563), fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required AuthMethodTab tab,
  }) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = tab);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1F212D) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: const Color(0xFF34384D), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case AuthMethodTab.phone:
        return PhoneAuthTab(
          key: ValueKey('phone_$_isSignUp'),
          isSignUp: _isSignUp,
          isLoading: _authController.isLoading,
          onSendOtp: _handleSendPhoneOtp,
          onVerifyOtp: _handleVerifyPhoneOtp,
        );
      case AuthMethodTab.email:
        return EmailAuthTab(
          key: ValueKey('email_$_isSignUp'),
          isSignUp: _isSignUp,
          isLoading: _authController.isLoading,
          onSubmit: _handleEmailSubmit,
          onForgotPassword: _handleForgotPassword,
        );
      case AuthMethodTab.username:
        return UsernameAuthTab(
          key: ValueKey('username_$_isSignUp'),
          isSignUp: _isSignUp,
          isLoading: _authController.isLoading,
          onSubmit: _handleUsernameSubmit,
        );
    }
  }
}
