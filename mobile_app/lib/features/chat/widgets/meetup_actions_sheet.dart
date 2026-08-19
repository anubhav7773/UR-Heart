import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'meetup_spots_sheet.dart';
import 'safe_bridge_paywall_sheet.dart';

class MeetupActionsSheet extends StatelessWidget {
  final String matchId;
  final String partnerName;
  final int totalMessages;
  final bool isWhatsAppUnlocked;
  final bool isLocationUnlocked;
  final String? partnerPhone;
  final String? partnerMapsUrl;
  final bool myWhatsAppConsent;
  final bool partnerWhatsAppConsent;
  final bool myLocationConsent;
  final bool partnerLocationConsent;
  final bool myMeetupConsent;
  final bool partnerMeetupConsent;
  final bool isMeetupUnlocked;
  final bool myBridgePaid;
  final bool partnerBridgePaid;
  final VoidCallback onLaunchWhatsApp;
  final VoidCallback onLaunchGoogleMaps;
  final Function(MeetupSpot spot) onSuggestSpotInChat;
  final Function(bool agree) onVoteMeetupConsent;
  final VoidCallback onRefreshStatus;

  const MeetupActionsSheet({
    super.key,
    required this.matchId,
    required this.partnerName,
    required this.totalMessages,
    required this.isWhatsAppUnlocked,
    required this.isLocationUnlocked,
    this.partnerPhone,
    this.partnerMapsUrl,
    this.myWhatsAppConsent = false,
    this.partnerWhatsAppConsent = false,
    this.myLocationConsent = false,
    this.partnerLocationConsent = false,
    required this.myMeetupConsent,
    required this.partnerMeetupConsent,
    required this.isMeetupUnlocked,
    required this.myBridgePaid,
    required this.partnerBridgePaid,
    required this.onLaunchWhatsApp,
    required this.onLaunchGoogleMaps,
    required this.onSuggestSpotInChat,
    required this.onVoteMeetupConsent,
    required this.onRefreshStatus,
  });

  static Future<void> show({
    required BuildContext context,
    required String matchId,
    required String partnerName,
    required int totalMessages,
    required bool isWhatsAppUnlocked,
    required bool isLocationUnlocked,
    String? partnerPhone,
    String? partnerMapsUrl,
    bool myWhatsAppConsent = false,
    bool partnerWhatsAppConsent = false,
    bool myLocationConsent = false,
    bool partnerLocationConsent = false,
    required bool myMeetupConsent,
    required bool partnerMeetupConsent,
    required bool isMeetupUnlocked,
    required bool myBridgePaid,
    required bool partnerBridgePaid,
    required VoidCallback onLaunchWhatsApp,
    required VoidCallback onLaunchGoogleMaps,
    required Function(MeetupSpot spot) onSuggestSpotInChat,
    required Function(bool agree) onVoteMeetupConsent,
    required VoidCallback onRefreshStatus,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetupActionsSheet(
        matchId: matchId,
        partnerName: partnerName,
        totalMessages: totalMessages,
        isWhatsAppUnlocked: isWhatsAppUnlocked,
        isLocationUnlocked: isLocationUnlocked,
        partnerPhone: partnerPhone,
        partnerMapsUrl: partnerMapsUrl,
        myWhatsAppConsent: myWhatsAppConsent,
        partnerWhatsAppConsent: partnerWhatsAppConsent,
        myLocationConsent: myLocationConsent,
        partnerLocationConsent: partnerLocationConsent,
        myMeetupConsent: myMeetupConsent,
        partnerMeetupConsent: partnerMeetupConsent,
        isMeetupUnlocked: isMeetupUnlocked,
        myBridgePaid: myBridgePaid,
        partnerBridgePaid: partnerBridgePaid,
        onLaunchWhatsApp: onLaunchWhatsApp,
        onLaunchGoogleMaps: onLaunchGoogleMaps,
        onSuggestSpotInChat: onSuggestSpotInChat,
        onVoteMeetupConsent: onVoteMeetupConsent,
        onRefreshStatus: onRefreshStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBridgeActive =
        isWhatsAppUnlocked || isLocationUnlocked || (myBridgePaid && partnerBridgePaid);
    final bool bothMeetupAgreed =
        isMeetupUnlocked || (myMeetupConsent && partnerMeetupConsent);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.cardBorderColor, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.secondaryColor.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppTheme.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Safe Meet & Contact Bridge',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bothMeetupAgreed
                                ? 'Mutual Meetup Confirmed • All features active'
                                : (isBridgeActive
                                    ? 'Safe Contact Active • ₹499 Unlocked'
                                    : 'Milestone ($totalMessages/15 Messages)'),
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedTextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppTheme.mutedTextColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.cardBorderColor, height: 1),
              const SizedBox(height: 16),

              // Action Tiles Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 1. WhatsApp Action Tile
                    _buildActionTile(
                      icon: Icons.chat_rounded,
                      iconColor: Colors.greenAccent,
                      title: 'Chat on WhatsApp',
                      subtitle: isWhatsAppUnlocked
                          ? (partnerPhone != null ? partnerPhone! : 'WhatsApp ready')
                          : 'Requires mutual consent & ₹499 unlock',
                      buttonLabel: isWhatsAppUnlocked ? 'Open Chat' : 'Unlock',
                      buttonColor: Colors.greenAccent.shade700,
                      isEnabled: isWhatsAppUnlocked,
                      onTap: isWhatsAppUnlocked
                          ? () {
                              Navigator.pop(context);
                              onLaunchWhatsApp();
                            }
                          : () {
                              Navigator.pop(context);
                              _openPaywall(context);
                            },
                    ),

                    const SizedBox(height: 10),

                    // 2. Google Maps Route Tile
                    _buildActionTile(
                      icon: Icons.navigation_rounded,
                      iconColor: AppTheme.secondaryColor,
                      title: 'Open Route in Google Maps',
                      subtitle: isLocationUnlocked
                          ? 'Direct navigation route to partner'
                          : 'Requires mutual consent & ₹499 unlock',
                      buttonLabel: isLocationUnlocked ? 'Navigate' : 'Unlock',
                      buttonColor: AppTheme.secondaryColor,
                      isEnabled: isLocationUnlocked,
                      onTap: isLocationUnlocked
                          ? () {
                              Navigator.pop(context);
                              onLaunchGoogleMaps();
                            }
                          : () {
                              Navigator.pop(context);
                              _openPaywall(context);
                            },
                    ),

                    const SizedBox(height: 10),

                    // 3. Meetup Spot Radar Tile
                    _buildActionTile(
                      icon: Icons.place_rounded,
                      iconColor: AppTheme.primaryColor,
                      title: 'Nearby Date Spot Radar',
                      subtitle: 'Tea tapris, cafes, restaurants & hotels sorted nearest first',
                      buttonLabel: 'Explore Spots',
                      buttonColor: AppTheme.primaryColor,
                      isEnabled: true,
                      onTap: () {
                        Navigator.pop(context);
                        MeetupSpotsSheet.show(
                          context: context,
                          onSuggestSpot: onSuggestSpotInChat,
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // 4. In-Sheet Meetup Voting Card
                    if (isBridgeActive)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bothMeetupAgreed
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: bothMeetupAgreed ? AppTheme.primaryColor : AppTheme.cardBorderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  bothMeetupAgreed ? Icons.celebration_rounded : Icons.handshake_rounded,
                                  color: bothMeetupAgreed ? AppTheme.primaryColor : AppTheme.secondaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bothMeetupAgreed
                                        ? 'Mutual Meetup Confirmed (2/2)'
                                        : (myMeetupConsent && !partnerMeetupConsent
                                            ? 'Waiting for match partner (1/2)'
                                            : 'Plan a Safe In-Person Meetup?'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (!bothMeetupAgreed) ...[
                              if (myMeetupConsent && !partnerMeetupConsent)
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Aapne haan bola hai. Response ka wait kar rahe hain...',
                                        style: TextStyle(fontSize: 11, color: AppTheme.mutedTextColor),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        onVoteMeetupConsent(false);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Cancel', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          onVoteMeetupConsent(true);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        child: const Text('✓ Haan, bilkul', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          onVoteMeetupConsent(false);
                                          Navigator.pop(context);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.mutedTextColor,
                                          side: const BorderSide(color: AppTheme.cardBorderColor),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        child: const Text('✕ Abhi nahi', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // 5. Manage Paywall / Sharing Settings Button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openPaywall(context);
                      },
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Manage Safe Bridge Settings (₹499)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: AppTheme.cardBorderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 42),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color buttonColor,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.mutedTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled ? buttonColor : AppTheme.surfaceColor,
              foregroundColor: isEnabled ? Colors.white : AppTheme.mutedTextColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            child: Text(
              buttonLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isEnabled ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    SafeBridgePaywallSheet.show(
      context: context,
      matchId: matchId,
      partnerName: partnerName,
      totalMessages: totalMessages,
      initialMyWhatsapp: myWhatsAppConsent,
      initialMyLocation: myLocationConsent,
      initialPartnerWhatsapp: partnerWhatsAppConsent,
      initialPartnerLocation: partnerLocationConsent,
      initialMyPaid: myBridgePaid,
      initialPartnerPaid: partnerBridgePaid,
      initialIsUnlocked: isWhatsAppUnlocked || isLocationUnlocked,
      initialPartnerPhone: partnerPhone,
      initialPartnerMapsUrl: partnerMapsUrl,
      onStateChanged: onRefreshStatus,
    );
  }
}
