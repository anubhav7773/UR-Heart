import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../data/chat_websocket_service.dart';

/// Progress badge & multi-platform deep-linker for Sacred Contact Bridge (ACT-03 Fix)
class SacredBridgeAppBarAction extends StatelessWidget {
  final String matchId;
  final bool isDark;
  final Map<String, dynamic> bridgeData;
  final ChatWebSocketService? wsService;

  const SacredBridgeAppBarAction({
    super.key,
    required this.matchId,
    required this.isDark,
    required this.bridgeData,
    this.wsService,
  });

  @override
  Widget build(BuildContext context) {
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surfaceMuted = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final waKeyColor = isDark ? DarkSanctuaryTokens.badgeWaKey : LightSanctuaryTokens.badgeWaKey;

    final isUnlocked = bridgeData['is_unlocked'] as bool? ?? false;
    final hasWaKey = bridgeData['has_wa_key'] as bool? ?? false;
    final platform = (bridgeData['platform'] as String? ?? 'whatsapp').toLowerCase();
    final userStep = bridgeData['user_step'] as int? ?? 1;

    // Direct WA Key unmasked compatibility badge
    if (hasWaKey && !isUnlocked) {
      return Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: () => _launchSacredBridgeIntent(platform, bridgeData['handle'] as String? ?? ''),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: waKeyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: waKeyColor.withValues(alpha: 0.4), width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.vpn_key_outlined, size: 12.0, color: waKeyColor),
                const SizedBox(width: 4.0),
                Text(
                  'WA Key ✓',
                  style: TextStyle(color: waKeyColor, fontSize: 11.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isUnlocked) {
      return Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showProgressionDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: gold),
                const SizedBox(width: 4),
                Text(
                  'Bridge ($userStep/3)',
                  style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: pine,
          elevation: 0,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.open_in_new, color: Colors.white, size: 12),
        label: Text(
          'Open ${platform.isNotEmpty ? platform[0].toUpperCase() + platform.substring(1) : "Bridge"}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _launchSacredBridgeIntent(platform, bridgeData['handle'] as String? ?? ''),
      ),
    );
  }

  void _showProgressionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sacred Enclave Bridge', style: TextStyle(fontFamily: 'Serif')),
        content: const Text(
          'Step forward in mutual trust. Proposing bridge progression signals readiness to reveal your chosen contact enclave.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // ACT-03 FIX: Real WebSocket Stage Advance Event
              wsService?.sendJsonPayload({
                'type': 'STAGE_ADVANCE_REQUEST',
                'match_id': matchId,
                'requested_at': DateTime.now().toIso8601String(),
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bridge progression proposed to your peer.')),
              );
            },
            child: const Text('Propose Step Progression ➔'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchSacredBridgeIntent(String platform, String rawHandle) async {
    Uri? targetUri;
    final handle = rawHandle.replaceAll('@', '').trim();

    switch (platform.toLowerCase()) {
      case 'whatsapp':
        final cleanPhone = handle.replaceAll(RegExp(r'[^0-9]'), '');
        targetUri = Uri.parse('https://wa.me/$cleanPhone');
        break;
      case 'instagram':
        targetUri = Uri.parse('https://instagram.com/$handle');
        break;
      case 'snapchat':
        targetUri = Uri.parse('https://snapchat.com/add/$handle');
        break;
      case 'telegram':
        targetUri = Uri.parse('https://t.me/$handle');
        break;
      case 'signal':
        targetUri = Uri.parse('https://signal.me/#p/$handle');
        break;
    }

    if (targetUri != null && await canLaunchUrl(targetUri)) {
      await launchUrl(targetUri, mode: LaunchMode.externalApplication);
    }
  }
}
