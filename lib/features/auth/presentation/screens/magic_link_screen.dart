import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/magic_link_passage_card.dart';

/// Screen 3: Sacred Magic Link & Live Step Passage Screen
/// 100% Passkey-Free: Streamlined tap-to-verify flow.
/// User registers with email & password -> Sacred link dispatched ->
/// User opens mail and taps link -> Instantly verifies ->
/// Enters Profile Sanctuary (/profile-setup) to complete profile.
/// Live step counting tracks:
/// Step 1: Dispatched (Delivered)
/// Step 2: Listening for Link Tap (Live seconds counter)
/// Step 3: Verified & Sacred Sanctuary Entry
class MagicLinkScreen extends ConsumerStatefulWidget {
  final String? email;

  const MagicLinkScreen({super.key, this.email});

  static const String routeName = '/verify-email';

  @override
  ConsumerState<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

class _MagicLinkScreenState extends ConsumerState<MagicLinkScreen> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _pollingTimer;
  Timer? _elapsedTimer;

  int _currentStep = 2; // Step 1 is already dispatched upon signup
  int _elapsedSeconds = 0;
  bool _isNavigating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
    _startLiveElapsedTimer();
    _startLiveStatusPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(authControllerProvider);
      final email = widget.email ?? state.email;
      if (email.isNotEmpty && state.resendCooldownSeconds == 0) {
        ref.read(authControllerProvider.notifier).resendVerificationEmail(email);
      }
    });
  }

  void _startLiveElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentStep < 3) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _startLiveStatusPolling() {
    _pollingTimer?.cancel();
    // Poll every 1.8 seconds to instantly detect when user taps the email link in their mail app / browser
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) async {
      if (!mounted || _currentStep == 3 || _isNavigating) return;

      final state = ref.read(authControllerProvider);
      final email = widget.email ?? state.email;
      if (email.isEmpty) return;

      try {
        final isVerified = await ref
            .read(authControllerProvider.notifier)
            .pollVerificationStatus(email);

        if (isVerified && mounted && !_isNavigating) {
          await _onVerificationSuccess();
        }
      } catch (_) {
        // Silent polling resilience
      }
    });
  }

  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        final linkStr = uri.toString();

        // 1. Native Firebase Auth Email Link Verification
        if (FirebaseAuth.instance.isSignInWithEmailLink(linkStr)) {
          final cleanEmail = widget.email ?? ref.read(authControllerProvider).email;
          try {
            final userCred = await FirebaseAuth.instance.signInWithEmailLink(
              email: cleanEmail,
              emailLink: linkStr,
            );
            if (userCred.user != null) {
              final idToken = await userCred.user!.getIdToken();
              if (idToken != null) {
                await SecureSessionStorage.instance.saveAuthToken(idToken);
              }
              await SecureSessionStorage.instance.saveUserSession(
                userId: userCred.user!.uid,
                email: userCred.user!.email ?? cleanEmail,
                isProfileCompleted: false,
              );
              await _onVerificationSuccess();
              return;
            }
          } catch (e) {
            debugPrint('[AUTH] Firebase signInWithEmailLink error: $e');
          }
        }

        // 2. Sanctuary Cryptographic Deep Link Verification
        if ((uri.scheme == 'urheart' && uri.host == 'auth' && uri.path.contains('verify')) ||
            ((uri.host.contains('urheart.asiverticals.me') ||
              uri.host.contains('ur-heart.onrender.com') ||
              uri.host.contains('firebaseapp.com')) &&
             (uri.path.contains('auth') || uri.path.contains('verify')))) {
          final token = uri.queryParameters['token'] ?? uri.queryParameters['code'];
          if (token != null && token.isNotEmpty) {
            await _verifyMagicLinkToken(token);
          }
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _errorMessage = 'Deep link listener interrupted.');
        }
      },
    );
  }

  Future<void> _verifyMagicLinkToken(String token) async {
    if (_isNavigating) return;
    setState(() => _errorMessage = null);

    try {
      final authNotifier = ref.read(authControllerProvider.notifier);
      final isSuccess = await authNotifier.verifyMagicLink(
        token,
        email: widget.email,
      );

      if (isSuccess && mounted) {
        await _onVerificationSuccess();
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Invalid or expired magic link. Please tap "Resend Verification Link".';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Verification failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _onVerificationSuccess() async {
    if (_isNavigating) return;
    _isNavigating = true;

    _pollingTimer?.cancel();
    _elapsedTimer?.cancel();

    HapticFeedback.heavyImpact();

    if (mounted) {
      setState(() {
        _currentStep = 3;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Sacred Email Verified! Entering Sanctuary...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1B4332),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Brief smooth pause for user to experience the live Step 3 completion tick
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final isCompleted = prefs.getBool('ur_heart_profile_setup_completed') ?? false;

    if (isCompleted) {
      Navigator.of(context).pushReplacementNamed('/sanctuary');
    } else {
      // Direct transition to Profile Sanctuary as requested
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    }
  }

  Future<void> _launchNativeEmailClient() async {
    final emailUri = Uri(scheme: 'mailto');
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please open your Gmail / Email app to tap the verification link.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open your Gmail / Email app to tap the verification link.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openDirectVerificationLink() async {
    final state = ref.read(authControllerProvider);
    final link = state.magicLinkUrl;
    if (link != null && link.isNotEmpty) {
      final uri = Uri.parse(link);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      // Fallback: verify directly with backend in-app
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        await _verifyMagicLinkToken(token);
      }
    }
  }

  void _copyMagicLink() {
    final state = ref.read(authControllerProvider);
    final link = state.magicLinkUrl;
    if (link != null && link.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sacred verification link copied to clipboard 📋'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _elapsedTimer?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    final bgColor = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final surfaceColor = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final textHeadline = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final textMuted = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final accentColor = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.accentTerracotta;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    final targetEmail = widget.email ?? (authState.email.isNotEmpty ? authState.email : 'your sanctuary inbox');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textHeadline),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sanctuary Dispatch Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pine.withValues(alpha: 0.12),
                  border: Border.all(color: pine.withValues(alpha: 0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: pine.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.mark_email_read_outlined, color: pine, size: 34),
              ),
              const SizedBox(height: 18),

              // Editorial Headline matching brand identity
              Text(
                'Almost home.',
                style: TextStyle(
                  fontFamily: 'Serif',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textHeadline,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Verify your sanctuary.',
                style: TextStyle(
                  fontFamily: 'Serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  fontWeight: FontWeight.normal,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We dispatched a sacred verification link to verify your genuine presence:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Target Email Pill with Edit Action
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email, size: 18.0, color: accentColor),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        targetEmail,
                        style: TextStyle(
                          color: textHeadline,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3-Step Live Count Mindful Passage Card
              MagicLinkPassageCard(
                currentStep: _currentStep,
                elapsedSeconds: _elapsedSeconds,
                targetEmail: targetEmail,
                onOpenEmailApp: _launchNativeEmailClient,
                onOpenDirectLink: _openDirectVerificationLink,
                onCopyLink: _copyMagicLink,
                onResend: () {
                  ref
                      .read(authControllerProvider.notifier)
                      .resendVerificationEmail(widget.email);
                },
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE63946),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Secondary manual help notice
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '💡 Note: You can tap the link from Gmail on your phone or any browser. UR-Heart will automatically detect your confirmation and bring you into the Sanctuary.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: textMuted.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
