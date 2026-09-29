import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../growth/presentation/controllers/growth_hub_controller.dart';

/// Sacred Kinship Referral Card with multi-channel social sharing
/// (WhatsApp, Telegram, X/Twitter, SMS, Native OS Share Sheet)
/// and real PostgreSQL referral code verification and redemption.
class SacredKinshipCard extends ConsumerStatefulWidget {
  final String referralCode;
  final bool isDark;

  const SacredKinshipCard({
    super.key,
    required this.referralCode,
    required this.isDark,
  });

  @override
  ConsumerState<SacredKinshipCard> createState() => _SacredKinshipCardState();
}

class _SacredKinshipCardState extends ConsumerState<SacredKinshipCard> {
  String? _localCachedCode;
  final TextEditingController _redeemController = TextEditingController();
  bool _isRedeeming = false;
  bool _showRedeemSection = false;

  @override
  void initState() {
    super.initState();
    _loadFallbackCode();
  }

  Future<void> _loadFallbackCode() async {
    if (widget.referralCode.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final code = prefs.getString('profile_referral_code') ??
            prefs.getString('ur_heart_user_referral_code');
        if (code != null && code.isNotEmpty && mounted) {
          setState(() {
            _localCachedCode = code;
          });
        }
      } catch (_) {}
    }
  }

  String get _effectiveReferralCode {
    if (widget.referralCode.isNotEmpty) return widget.referralCode;
    if (_localCachedCode != null && _localCachedCode!.isNotEmpty) {
      return _localCachedCode!;
    }
    return 'UR-SANCTUARY';
  }

  String get _shareLink =>
      'https://urheart.asiverticals.me/join?ref=$_effectiveReferralCode';

  String get _shareMessage =>
      'Join me in UR-Heart — A mindful dating sanctuary without superficial algorithms. '
      'Enter my sacred kinship referral code: $_effectiveReferralCode\n$_shareLink';

  Future<void> _shareToWhatsApp() async {
    final encoded = Uri.encodeComponent(_shareMessage);
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await _shareViaSystemSheet();
      }
    } catch (_) {
      await _shareViaSystemSheet();
    }
  }

  Future<void> _shareToTelegram() async {
    final encodedMsg = Uri.encodeComponent(_shareMessage);
    final encodedUrl = Uri.encodeComponent(_shareLink);
    final tgUri =
        Uri.parse('https://t.me/share/url?url=$encodedUrl&text=$encodedMsg');

    try {
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      } else {
        await _shareViaSystemSheet();
      }
    } catch (_) {
      await _shareViaSystemSheet();
    }
  }

  Future<void> _shareToTwitter() async {
    final encodedMsg = Uri.encodeComponent(
        'Step into intentional connection on @URHeartApp. Use my Kinship code: $_effectiveReferralCode');
    final encodedUrl = Uri.encodeComponent(_shareLink);
    final twitterUri =
        Uri.parse('https://twitter.com/intent/tweet?text=$encodedMsg&url=$encodedUrl');

    try {
      if (await canLaunchUrl(twitterUri)) {
        await launchUrl(twitterUri, mode: LaunchMode.externalApplication);
      } else {
        await _shareViaSystemSheet();
      }
    } catch (_) {
      await _shareViaSystemSheet();
    }
  }

  Future<void> _shareViaSms() async {
    final encoded = Uri.encodeComponent(_shareMessage);
    final smsUri = Uri.parse('sms:?body=$encoded');

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        await _shareViaSystemSheet();
      }
    } catch (_) {
      await _shareViaSystemSheet();
    }
  }

  Future<void> _shareViaSystemSheet() async {
    try {
      await Share.share(
        _shareMessage,
        subject: 'UR-Heart Sanctuary Kinship Invitation',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open share sheet: $e')),
        );
      }
    }
  }

  Future<void> _redeemCode() async {
    final code = _redeemController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid referral code.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isRedeeming = true);
    try {
      final msg = await ref
          .read(growthHubControllerProvider.notifier)
          .redeemReferralCode(code);
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _showRedeemSection = false;
          _redeemController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: const Color(0xFF1B4332),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRedeeming = false);
        final err = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: const Color(0xFFC94A29),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _redeemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final code = _effectiveReferralCode;

    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.sanctuaryPine;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final codeBoxBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.chipBackground;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diversity_1_outlined, color: accentColor, size: 22.0),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  'Sacred Kinship Referral',
                  style: AppTypography.titleH2
                      .copyWith(color: headlineColor, fontSize: 17.0),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+20 Reflections',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'Share your sanctuary invitation with kindred spirits across any platform. '
            'When they enter, both souls receive 20 bonus reflections instantly.',
            style: TextStyle(color: mutedColor, fontSize: 12.0, height: 1.35),
          ),
          const SizedBox(height: 14.0),

          // Real Referral Code Display Card
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: codeBoxBg,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'YOUR SACRED CODE',
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        code,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 18.0,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Referral Code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Referral code $code copied to clipboard!'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.copy_outlined, size: 18.0, color: headlineColor),
                ),
                IconButton(
                  tooltip: 'Copy Invitation Link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _shareLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kinship invite link copied to clipboard!'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.link_rounded, size: 20.0, color: accentColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Multi-Platform Social Share Row
          Text(
            'SHARE ACROSS ALL CHANNELS',
            style: TextStyle(
              color: mutedColor,
              fontSize: 10.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSocialShareButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: _shareToWhatsApp,
                isDark: isDark,
              ),
              _buildSocialShareButton(
                icon: Icons.send_rounded,
                label: 'Telegram',
                color: const Color(0xFF0088CC),
                onTap: _shareToTelegram,
                isDark: isDark,
              ),
              _buildSocialShareButton(
                icon: Icons.tag_rounded,
                label: 'X (Twitter)',
                color: isDark ? Colors.white : const Color(0xFF14171A),
                onTap: _shareToTwitter,
                isDark: isDark,
              ),
              _buildSocialShareButton(
                icon: Icons.sms_outlined,
                label: 'SMS',
                color: const Color(0xFFE58B68),
                onTap: _shareViaSms,
                isDark: isDark,
              ),
              _buildSocialShareButton(
                icon: Icons.share_rounded,
                label: 'More',
                color: accentColor,
                onTap: _shareViaSystemSheet,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Primary Quick Action: Native System Share Sheet
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onPressed: _shareViaSystemSheet,
              icon: const Icon(Icons.share_outlined, size: 18.0),
              label: const Text(
                'Share Invitation Everywhere ➔',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10.0),

          // Redeem Kinship Code Toggle
          InkWell(
            onTap: () {
              setState(() {
                _showRedeemSection = !_showRedeemSection;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _showRedeemSection
                          ? 'Hide Referral Code Entry ▲'
                          : 'Have a referral code? Enter here ▼',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Redeem Code Input Section
          if (_showRedeemSection) ...[
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141C19) : const Color(0xFFF3F5F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENTER FRIEND\'S REFERRAL CODE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: mutedColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _redeemController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            color: headlineColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. UR-A9B8C7',
                            hintStyle: TextStyle(
                              color: mutedColor.withOpacity(0.5),
                              letterSpacing: 1.0,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E9F76),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isRedeeming ? null : _redeemCode,
                        child: _isRedeeming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Redeem',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final chipBg = isDark ? const Color(0xFF141C19) : const Color(0xFFF3F5F4);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25), width: 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF2D3748),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
