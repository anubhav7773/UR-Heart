import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// Production-Grade Genuine Hardware Video KYC Capture Modal (DUM-16 & ACT-21 Fix)
/// Connects physical front camera, records 3-second biometric glance,
/// purges dummy blank byte arrays, and dispatches true MP4/video bytes to backend.
class LiveKycRecordingModal extends ConsumerStatefulWidget {
  final String anchorPhotoBase64;
  final void Function(bool isVerified, String message)? onKycCompleted;

  const LiveKycRecordingModal({
    super.key,
    this.anchorPhotoBase64 = '',
    this.onKycCompleted,
  });

  @override
  ConsumerState<LiveKycRecordingModal> createState() => _LiveKycRecordingModalState();
}

class _LiveKycRecordingModalState extends ConsumerState<LiveKycRecordingModal> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isRecording = false;
  bool _isUploading = false;
  int _recordingSeconds = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeFrontCamera();
  }

  Future<void> _initializeFrontCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _isCameraReady = false);
        return;
      }

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      _cameraController = controller;
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;
    final surface = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final sub = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: sub.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Live Sanctuary Liveness Reflection',
            style: TextStyle(fontFamily: 'Serif', fontSize: 18, fontWeight: FontWeight.bold, color: primary),
          ),
          const SizedBox(height: 6),
          Text(
            'Record a 3-second quiet glance to verify genuine human presence. Audio is never recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: sub, height: 1.35),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              width: 180,
              height: 180,
              child: _isCameraReady && _cameraController != null
                  ? CameraPreview(_cameraController!)
                  : Container(
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (_isRecording)
            Text(
              'Recording reflection: $_recordingSeconds seconds remaining...',
              style: TextStyle(color: pine, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pine,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_isCameraReady && !_isRecording && !_isUploading)
                  ? _startLivenessCapture
                  : null,
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_isRecording ? 'Capturing Biometric Glance...' : 'Begin 3-Second Glance ➔',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startLivenessCapture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 3;
      });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_recordingSeconds > 1) {
          if (mounted) setState(() => _recordingSeconds--);
        } else {
          timer.cancel();
          final XFile videoFile = await controller.stopVideoRecording();
          if (mounted) {
            setState(() {
              _isRecording = false;
              _isUploading = true;
            });
          }
          await _dispatchRealVideoToBackend(File(videoFile.path));
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _dispatchRealVideoToBackend(File videoFile) async {
    try {
      final Uint8List videoBytes = await videoFile.readAsBytes();
      final String videoB64 = base64Encode(videoBytes);

      // Execute controller update for reactive UI updates
      try {
        await ref
            .read(profileSetupControllerProvider.notifier)
            .executeVideoKyc(videoBytes: videoBytes);
      } catch (_) {}

      // Resolve anchor photo
      String anchor = widget.anchorPhotoBase64;
      if (anchor.isEmpty) {
        final profileState = ref.read(profileSetupControllerProvider);
        final slot1Path = profileState.photoSlots[1];
        if (slot1Path != null && await File(slot1Path).exists()) {
          final slotBytes = await File(slot1Path).readAsBytes();
          anchor = base64Encode(slotBytes);
        } else {
          anchor = '';
        }
      }

      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/kyc/verify-live',
        data: {
          'anchor_b64': anchor,
          'video_b64': videoB64,
        },
      );

      final status = response.data?['status'] as String? ?? 'pending_manual_review';
      final isApproved = status == 'approved' || response.data?['is_live_human'] == true;
      final message = response.data?['detail'] as String? ??
          (response.data?['rejection_reason'] as String?) ??
          'Reflection submitted to Sanctuary Sentinel.';

      if (mounted) {
        Navigator.of(context).pop();
        widget.onKycCompleted?.call(isApproved, message);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onKycCompleted?.call(false, 'Verification service timed out. Routed for manual review.');
      }
    } finally {
      if (await videoFile.exists()) {
        await videoFile.delete(); // Ephemeral hygiene: purge temporary video capture
      }
    }
  }
}
