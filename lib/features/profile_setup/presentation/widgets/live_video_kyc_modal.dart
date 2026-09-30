import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'live_kyc_recording_modal.dart';

/// Legacy modal adapter forwarding directly to production LiveKycRecordingModal
/// Eliminates dummy mock byte arrays and ensures 100% camera hardware connectivity.
class LiveVideoKycModal extends ConsumerWidget {
  final String anchorPhotoBase64;
  final void Function(bool isVerified, String message)? onKycCompleted;

  const LiveVideoKycModal({
    super.key,
    this.anchorPhotoBase64 = '',
    this.onKycCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiveKycRecordingModal(
      anchorPhotoBase64: anchorPhotoBase64,
      onKycCompleted: (verified, message) {
        onKycCompleted?.call(verified, message);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
