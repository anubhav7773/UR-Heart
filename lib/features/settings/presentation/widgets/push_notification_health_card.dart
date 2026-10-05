import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/sanctuary_notification_service.dart';

/// Ultra-Premium Push Notification Delivery & Diagnostic Card
/// Allows seekers to verify Android system tray & lockscreen push delivery in real time
class PushNotificationHealthCard extends StatefulWidget {
  final bool isDark;

  const PushNotificationHealthCard({
    super.key,
    required this.isDark,
  });

  @override
  State<PushNotificationHealthCard> createState() => _PushNotificationHealthCardState();
}

class _PushNotificationHealthCardState extends State<PushNotificationHealthCard> {
  bool _isTesting = false;
  String? _statusFeedback;

  Future<void> _handleTestPush() async {
    setState(() {
      _isTesting = true;
      _statusFeedback = null;
    });

    try {
      final res = await SanctuaryNotificationService.instance.sendTestPush();
      if (!mounted) return;

      if (res['ok'] == true || res['status'] == 'success') {
        setState(() {
          _statusFeedback = '🔔 Push delivered! Press Home to see it in your status bar.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Push sent! Press Home to check your system tray & lockscreen.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: widget.isDark
                ? DarkSanctuaryTokens.secondaryPine
                : LightSanctuaryTokens.primaryPine,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final err = res['error']?.toString() ?? 'Unable to send push test.';
        setState(() {
          _statusFeedback = '⚠️ $err';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusFeedback = '⚠️ Test push failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _handleRequestPermission() async {
    await SanctuaryNotificationService.instance.requestWebNotificationPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification permissions requested.'),
          backgroundColor: widget.isDark
              ? DarkSanctuaryTokens.secondaryPine
              : LightSanctuaryTokens.primaryPine,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = widget.isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = widget.isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = widget.isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    const goldAccent = Color(0xFFD4AF37);
    const pineAccent = Color(0xFF1B4332);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 20,
                  color: goldAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outside-the-App Push Delivery',
                      style: AppTypography.titleH2.copyWith(
                        fontSize: 15,
                        color: headlineColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Heads-up system tray & lockscreen alerts',
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 12, color: Color(0xFF52B788)),
                    SizedBox(width: 2),
                    Text(
                      'FCM v1 Armed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF52B788),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Delivers WhatsApp-grade instant notifications for incoming messages, sparks, and streak warnings even when the app is closed or killed.',
            style: AppTypography.bodySmall.copyWith(
              color: mutedColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (_statusFeedback != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? DarkSanctuaryTokens.inputBackground
                    : LightSanctuaryTokens.chipBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusFeedback!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: headlineColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleRequestPermission,
                  icon: const Icon(Icons.security, size: 14),
                  label: const Text(
                    'Permissions',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: headlineColor,
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isTesting ? null : _handleTestPush,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(
                    _isTesting ? 'Sending Push...' : 'Test Background Push',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pineAccent,
                    foregroundColor: const Color(0xFFD4AF37),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: goldAccent.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
