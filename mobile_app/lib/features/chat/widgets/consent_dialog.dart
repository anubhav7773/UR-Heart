import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ConsentDialogResult {
  final bool shareWhatsapp;
  final bool shareLocation;

  const ConsentDialogResult({
    required this.shareWhatsapp,
    required this.shareLocation,
  });
}

class ConsentDialog extends StatefulWidget {
  final bool initialShareWhatsapp;
  final bool initialShareLocation;
  final String partnerName;
  final bool partnerWhatsAppConsent;
  final bool partnerLocationConsent;

  const ConsentDialog({
    super.key,
    this.initialShareWhatsapp = false,
    this.initialShareLocation = false,
    this.partnerName = 'Matched User',
    this.partnerWhatsAppConsent = false,
    this.partnerLocationConsent = false,
  });

  static Future<ConsentDialogResult?> show({
    required BuildContext context,
    bool initialShareWhatsapp = false,
    bool initialShareLocation = false,
    String partnerName = 'Matched User',
    bool partnerWhatsAppConsent = false,
    bool partnerLocationConsent = false,
  }) {
    return showDialog<ConsentDialogResult>(
      context: context,
      builder: (context) => ConsentDialog(
        initialShareWhatsapp: initialShareWhatsapp,
        initialShareLocation: initialShareLocation,
        partnerName: partnerName,
        partnerWhatsAppConsent: partnerWhatsAppConsent,
        partnerLocationConsent: partnerLocationConsent,
      ),
    );
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  late bool _shareWhatsapp;
  late bool _shareLocation;

  @override
  void initState() {
    super.initState();
    _shareWhatsapp = widget.initialShareWhatsapp;
    _shareLocation = widget.initialShareLocation;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '🔒 Safe Contact & Location Sharing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.tealAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dono users ki sehmati ke baad hi number aur location unlock honge.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Checkbox 1: WhatsApp
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _shareWhatsapp
                      ? Colors.greenAccent.withValues(alpha: 0.6)
                      : Colors.white12,
                ),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                value: _shareWhatsapp,
                activeColor: Colors.greenAccent.shade700,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: const Text(
                  'Share WhatsApp Number 💬',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: widget.partnerWhatsAppConsent
                    ? Text(
                        '${widget.partnerName} has already agreed! ✅',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                      )
                    : const Text(
                        'Mutual consent unlocks direct chat',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                onChanged: (val) {
                  setState(() {
                    _shareWhatsapp = val ?? false;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // Checkbox 2: Location / Google Maps
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _shareLocation
                      ? Colors.blueAccent.withValues(alpha: 0.6)
                      : Colors.white12,
                ),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                value: _shareLocation,
                activeColor: Colors.blueAccent,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: const Text(
                  'Share Live Route on Google Maps 📍',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: widget.partnerLocationConsent
                    ? Text(
                        '${widget.partnerName} has already agreed! ✅',
                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                      )
                    : const Text(
                        'Mutual consent unlocks turn-by-turn route',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                onChanged: (val) {
                  setState(() {
                    _shareLocation = val ?? false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(
              ConsentDialogResult(
                shareWhatsapp: _shareWhatsapp,
                shareLocation: _shareLocation,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Agree & Share',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
