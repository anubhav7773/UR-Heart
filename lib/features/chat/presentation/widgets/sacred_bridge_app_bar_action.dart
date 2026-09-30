import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../navigation/presentation/screens/sanctuary_navigation_shell.dart';
import '../../data/chat_websocket_service.dart';
import '../controllers/chat_dialogue_controller.dart';

/// Progress badge & multi-platform deep-linker for Sacred Contact Bridge
/// Enforces DPDP Act Section 11 & IT Rules 2021: Contact handle is NEVER revealed
/// without mutual Stage 3 confirmation or 1 verified Reveal Token (earned via 3 video ads).
class SacredBridgeAppBarAction extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surfaceMuted = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;

    final isUnlocked = bridgeData['is_unlocked'] as bool? ?? false;
    final platform = (bridgeData['platform'] as String? ?? 'whatsapp').toLowerCase();
    final userStep = bridgeData['user_step'] as int? ?? 1;
    final rawHandle = bridgeData['handle'] as String? ?? '';

    // If bridge is NOT yet unlocked, display lock badge with step progression
    if (!isUnlocked) {
      return Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showProgressionDialog(context, ref),
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

    // Unlocked: Display verified external enclave button
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
        onPressed: () {
          if (rawHandle.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact handle not yet configured by your partner.')),
            );
            return;
          }
          _launchSacredBridgeIntent(platform, rawHandle);
        },
      ),
    );
  }

  void _showProgressionDialog(BuildContext context, WidgetRef ref) {
    final revealTokens = bridgeData['reveal_tokens_count'] as int? ?? 0;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🕊️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Sacred Contact Bridge', style: TextStyle(fontFamily: 'Serif', fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Private contact handles (such as WhatsApp) are protected under AES-256 encryption. '
              'They are only unsealed when both seekers mutually confirm Stage 3 OR when you redeem 1 Sacred Bridge Reveal Token.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4332).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1B4332).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFB8860B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Reveal Tokens Available: $revealTokens',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          if (revealTokens > 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4332),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.key, size: 14, color: Colors.white),
              label: const Text('Unlock with 1 Token 🌟', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final ok = await ref
                    .read(chatDialogueControllerProvider(matchId).notifier)
                    .redeemBridgeRevealToken();
                if (context.mounted) {
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sacred Bridge Unlocked! Genuine contact handle revealed. ✨'),
                        backgroundColor: Color(0xFF1B4332),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to unlock bridge. Please try again.')),
                    );
                  }
                }
              },
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8860B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.video_library_outlined, size: 14, color: Colors.white),
              label: const Text('Earn Token (3 Videos) ➔', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(context).pop(); // Back to navigation shell
                ref.read(navigationIndexProvider.notifier).state = 3; // Growth Hub
              },
            ),
          OutlinedButton(
            onPressed: () {
              wsService?.sendJsonPayload({
                'type': 'STAGE_ADVANCE_REQUEST',
                'match_id': matchId,
                'requested_at': DateTime.now().toIso8601String(),
              });
              Navigator.of(dialogCtx).pop();
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
