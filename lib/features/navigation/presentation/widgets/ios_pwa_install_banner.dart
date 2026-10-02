import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Lightweight, elegant banner educating iOS Safari seekers how to install
/// UR-Heart directly to their iPhone/iPad Home Screen for $0 with zero App Store friction.
class IosPwaInstallBanner extends StatefulWidget {
  final bool isDark;

  const IosPwaInstallBanner({super.key, required this.isDark});

  @override
  State<IosPwaInstallBanner> createState() => _IosPwaInstallBannerState();
}

class _IosPwaInstallBannerState extends State<IosPwaInstallBanner> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkIosWebEligibility();
  }

  Future<void> _checkIosWebEligibility() async {
    // Show only on Web for iOS devices
    if (!kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool('ur_heart_ios_pwa_dismissed') ?? false;
    if (!isDismissed && mounted) {
      setState(() => _isVisible = true);
    }
  }

  Future<void> _dismissBanner() async {
    setState(() => _isVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ur_heart_ios_pwa_dismissed', true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final gold = widget.isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = widget.isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primary = widget.isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final muted = widget.isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: gold.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.install_mobile, color: gold, size: 20.0),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  'Install UR-Heart on iPhone',
                  style: TextStyle(
                    fontFamily: 'Serif',
                    color: primary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: muted, size: 18.0),
                onPressed: _dismissBanner,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          RichText(
            text: TextSpan(
              style: TextStyle(color: muted, fontSize: 12.0, height: 1.4),
              children: [
                const TextSpan(text: 'Tap Safari\'s '),
                WidgetSpan(
                  child: Icon(Icons.ios_share, size: 14.0, color: gold),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(
                  text: ' Share button below, then choose ',
                ),
                TextSpan(
                  text: '"Add to Home Screen"',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: ' for full-screen native experience without App Store.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
