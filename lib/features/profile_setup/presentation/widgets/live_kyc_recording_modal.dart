import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// Production-Grade Genuine Hardware Video KYC Capture Modal (DUM-16, ACT-21 & WEB Parity)
/// Connects physical front camera / webcam, records 3-second biometric glance,
/// supports Web/Desktop fallback video upload, and dispatches true MP4/video bytes to backend.
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
  bool _cameraUnavailable = false;
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
        if (mounted) {
          setState(() {
            _isCameraReady = false;
            _cameraUnavailable = true;
          });
        }
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
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraUnavailable = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _cameraUnavailable = true;
        });
      }
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
            _cameraUnavailable
                ? 'Webcam / camera not detected. You can upload a short 3-second selfie clip.'
                : 'Glance gently into the camera for 3 seconds to verify authenticity.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(90),
            child: SizedBox(
              width: 180,
              height: 180,
              child: _isCameraReady && _cameraController != null
                  ? CameraPreview(_cameraController!)
                  : Container(
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: Center(
                        child: _cameraUnavailable
                            ? Icon(Icons.videocam_off_outlined, size: 48, color: sub)
                            : const CircularProgressIndicator(strokeWidth: 2),
                      ),
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
          if (!_cameraUnavailable)
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
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: pine, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isUploading ? null : _pickVideoFallback,
                icon: _isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.upload_file_rounded, color: pine),
                label: Text(
                  _isUploading ? 'Verifying...' : 'Upload 3-Second Clip',
                  style: TextStyle(color: pine, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickVideoFallback() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 10),
      );
      if (video != null) {
        setState(() => _isUploading = true);
        await _dispatchRealVideoToBackend(video);
      }
    } catch (_) {
      if (mounted) setState(() => _isUploading = false);
    }
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
          await _dispatchRealVideoToBackend(videoFile);
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

  Future<void> _dispatchRealVideoToBackend(XFile videoFile) async {
    try {
      final Uint8List videoBytes = await videoFile.readAsBytes();
      final String videoB64 = base64Encode(videoBytes);

      // Execute controller update for reactive UI updates
      try {
        await ref
            .read(profileSetupControllerProvider.notifier)
            .executeVideoKyc(videoBytes: videoBytes);
      } catch (_) {}

      // Resolve anchor photo in a cross-platform manner
      String anchor = widget.anchorPhotoBase64;
      if (anchor.isEmpty) {
        final profileState = ref.read(profileSetupControllerProvider);
        final slot1 = profileState.photoSlots[1];
        if (slot1 != null && slot1.isNotEmpty) {
          if (slot1.startsWith('data:') && slot1.contains(',')) {
            anchor = slot1.split(',').last;
          } else if (slot1.length > 200 && !slot1.startsWith('http') && !slot1.startsWith('/') && !slot1.startsWith('blob:')) {
            anchor = slot1;
          } else {
            try {
              final xFile = XFile(slot1);
              final bytes = await xFile.readAsBytes();
              anchor = base64Encode(bytes);
            } catch (_) {
              anchor = '';
            }
          }
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
    }
  }
}
