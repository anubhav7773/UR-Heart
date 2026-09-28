import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/magic_link_passage_card.dart';

/// Screen 3: Magic Link Verification Passage (ACT-01 Fix)
/// Guides user through genuine deep link verification with native mailto: launcher,
/// listening to urheart://auth/verify?token=... before proceeding to /profile-setup.
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
        if (uri.scheme == 'urheart' && uri.host == 'auth' && uri.path == '/verify') {
          final token = uri.queryParameters['token'];
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

  Future<void> _verifyMagicLinkToken(String token) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isSuccess = await ref.read(authControllerProvider.notifier).verifyMagicLink(token);
      if (isSuccess && mounted) {
        Navigator.of(context).pushReplacementNamed('/profile-setup');
      } else if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Invalid or expired magic link. Please request a new link.';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;
    final surface = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final sub = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    final targetEmail = widget.email ?? (authState.email.isNotEmpty ? authState.email : 'your sanctuary inbox');

    return Scaffold(
      backgroundColor: isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pine.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.mark_email_read_outlined, color: pine, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Sacred Passage Dispatched',
                style: TextStyle(fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold, color: primary),
              ),
              const SizedBox(height: 8),
              Text(
                'A single-use mindful link was transmitted to:\n$targetEmail\nTap the link in your mailbox to enter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: sub, height: 1.45),
              ),
              const SizedBox(height: 20),
              // Email Summary Card with Edit Action
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: sub.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, size: 18.0, color: sub),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        targetEmail,
                        style: TextStyle(
                          color: primary,
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
                        style: TextStyle(color: pine, fontWeight: FontWeight.bold, fontSize: 13.0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const MagicLinkPassageCard(),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? DarkSanctuaryTokens.dangerBorder : LightSanctuaryTokens.dangerBorder,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pine,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isVerifying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.mail_outline, color: Colors.white, size: 18),
                  label: Text(
                    _isVerifying ? 'Verifying Passage...' : 'Open Email App ➔',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isVerifying ? null : _launchNativeEmailClient,
                ),
              ),
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
