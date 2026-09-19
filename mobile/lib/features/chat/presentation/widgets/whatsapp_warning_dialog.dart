import 'package:flutter/material.dart';

class WhatsAppWarningDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const WhatsAppWarningDialog({super.key, required this.onConfirm});

  static Future<void> show(BuildContext context, {required VoidCallback onConfirm}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WhatsAppWarningDialog(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16161D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD166), size: 24),
          SizedBox(width: 8),
          Text(
            "Statutory Safety Warning",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "\"Never share financial details. Platform is not liable for offline interactions outside the app.\"",
            style: TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "For legal protection and compliance, this number reveal request will be logged with your timestamp and IP address. Report suspicious behavior immediately.",
            style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, height: 1.3),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text("I Understand & Reveal", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
