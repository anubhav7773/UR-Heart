import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/magic_link_passage_card.dart';

/// Screen 3: Magic Link & Mindful Passkey Verification Passage (ACT-01 Production Fix)
/// Supports real Supabase Auth deep links (urheart://auth/verify?token=...), native mail launcher,
/// and instant 6-digit mindful passkey direct verification with session JWT issuance.
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
  final TextEditingController _passkeyController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        if ((uri.scheme == 'urheart' && uri.host == 'auth' && uri.path == '/verify') ||
            (uri.host.contains('urheart.app') && uri.path.contains('auth'))) {
          final token = uri.queryParameters['token'] ?? uri.queryParameters['code'];
          if (token != null && token.isNotEmpty) {
            await _verifyMagicLinkToken(token);
          }
        }
      },
      onError: (_) {
        if (mounted) setState(() => _errorMessage = 'Deep link listener interrupted.');
      },
    );
  }

  Future<void> _verifyMagicLinkToken(String tokenOrPasskey) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authControllerProvider.notifier);
      final isSuccess = await authNotifier.verifyMagicLink(
        tokenOrPasskey,
        email: widget.email,
      );

      if (isSuccess && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final isCompleted = prefs.getBool('ur_heart_profile_setup_completed') ?? false;
        if (!mounted) return;
        if (isCompleted) {
          Navigator.of(context).pushReplacementNamed('/sanctuary');
        } else {
          Navigator.of(context).pushReplacementNamed('/profile-setup');
        }
      } else if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Invalid or expired magic link / passkey. Please request a new link.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Verification failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _passkeyController.dispose();
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pine.withValues(alpha: 0.12),
                  border: Border.all(color: pine.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.mark_email_read_outlined, color: pine, size: 32),
              ),
              const SizedBox(height: 16),

              // Editorial Headline matching spec exactly
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
                'We have dispatched an encrypted invitation link to confirm your genuine space:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Email Pill with Edit Action
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
                        'Edit',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13.0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3-Step Mindful Passage Card
              const MagicLinkPassageCard(),
              const SizedBox(height: 16),

              // Mindful 6-Digit Passkey Direct Input Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pin_outlined, size: 18, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Mindful 6-Digit Passkey',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textHeadline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Prefer typing a code? Enter the 6-digit passkey sent with your invitation:',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passkeyController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: textHeadline,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          letterSpacing: 6,
                          color: textMuted.withValues(alpha: 0.3),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141C19) : const Color(0xFFF3F5F4),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.trim().length == 6) {
                          _verifyMagicLinkToken(val.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isVerifying
                            ? null
                            : () {
                                final code = _passkeyController.text.trim();
                                if (code.isNotEmpty) {
                                  _verifyMagicLinkToken(code);
                                } else {
                                  setState(() => _errorMessage = 'Please enter your 6-digit passkey.');
                                }
                              },
                        child: _isVerifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Verify Passkey & Enter ➔',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? DarkSanctuaryTokens.dangerBorder : LightSanctuaryTokens.dangerBorder,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Primary CTA: Open Email App
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: pine, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text(
                    'Open Email App ➔',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _launchNativeEmailClient,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchNativeEmailClient() async {
    final emailUri = Uri(scheme: 'mailto');
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please open your mail client manually.')),
        );
      }
    }
  }
}
