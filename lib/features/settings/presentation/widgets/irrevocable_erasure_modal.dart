import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/settings_controller.dart';
export 'sovereign_control_section.dart';

/// DPDP Act Sec 12 Account Shredder Modal (< 140 lines)
class IrrevocableErasureModal extends ConsumerStatefulWidget {
  final bool isDark;
  final VoidCallback? onConfirmErasure;

  const IrrevocableErasureModal({
    super.key,
    required this.isDark,
    this.onConfirmErasure,
  });

  @override
  ConsumerState<IrrevocableErasureModal> createState() => _IrrevocableErasureModalState();
}

class _IrrevocableErasureModalState extends ConsumerState<IrrevocableErasureModal> {
  final TextEditingController _confirmController = TextEditingController();
  bool _canShred = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primary = widget.isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final sub = widget.isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final danger = widget.isDark ? DarkSanctuaryTokens.crimsonDelete : LightSanctuaryTokens.crimsonDelete;

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: danger),
          const SizedBox(width: 8),
          Text(
            'Irrevocable Erasure',
            style: TextStyle(fontFamily: 'Serif', color: primary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action is mathematically non-reversible under DPDP Act 2023 Section 12. Your messages, moments, matches, and device credentials will be immediately shredded.',
            style: TextStyle(fontSize: 13, color: sub, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Type "ERASE" to authorize destruction:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            style: TextStyle(color: primary, fontWeight: FontWeight.bold, letterSpacing: 2),
            onChanged: (val) {
              setState(() => _canShred = val.trim().toUpperCase() == 'ERASE');
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: danger.withValues(alpha: 0.08),
              hintText: 'Type ERASE',
              hintStyle: TextStyle(color: sub.withValues(alpha: 0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: danger)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: sub)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _canShred ? danger : sub.withValues(alpha: 0.3),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: _canShred
              ? () {
                  Navigator.of(context).pop();
                  final cb = widget.onConfirmErasure;
                  if (cb != null) {
                    cb();
                  } else {
                    ref.read(settingsControllerProvider.notifier).executePermanentAccountErasure(context);
                  }
                }
              : null,
          child: const Text('Confirm Erasure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
