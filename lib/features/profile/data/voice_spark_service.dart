import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_session_storage.dart';

/// Provider for VoiceSparkService
final voiceSparkServiceProvider = Provider<VoiceSparkService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VoiceSparkService(apiClient: apiClient);
});

/// Production-grade Service managing Voice Spark audio recording, waveform streaming,
/// and backend persistence per DPDP Act 2023 directives.
class VoiceSparkService {
  final ApiClient _apiClient;
  final AudioRecorder _audioRecorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  VoiceSparkService({
    required ApiClient apiClient,
    AudioRecorder? audioRecorder,
  })  : _apiClient = apiClient,
        _audioRecorder = audioRecorder ?? AudioRecorder();

  /// Normalized amplitude stream (0.0 to 1.0) for live waveform UI pulsation
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Checks and requests hardware microphone permission
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('VoiceSparkService hasPermission error: $e');
      return false;
    }
  }

  /// Starts recording a 7-second Voice Spark
  Future<String> startRecording({String? customPath}) async {
    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw Exception('Microphone permission is required to record a Voice Spark.');
    }

    String path;
    if (customPath != null && customPath.isNotEmpty) {
      path = customPath;
    } else if (kIsWeb) {
      path = '';
    } else {
      final tempDir = Directory.systemTemp.path;
      path = '$tempDir/voice_spark_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    // Listen to real hardware decibels / amplitude
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      // Current decibels typically range from -60 dB (quiet) to 0 dB (loud)
      final currentDb = amp.current;
      double normalized = (currentDb + 60.0) / 60.0;
      if (normalized < 0.05) normalized = 0.05;
      if (normalized > 1.0) normalized = 1.0;
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(normalized);
      }
    });

    return path;
  }

  /// Stops recording and returns the path to the recorded audio file
  Future<String?> stopRecording() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      debugPrint('VoiceSparkService stopRecording error: $e');
      return null;
    }
  }

  /// Cancels recording and discards temporary buffer
  Future<void> cancelRecording() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    try {
      await _audioRecorder.cancel();
    } catch (e) {
      debugPrint('VoiceSparkService cancelRecording error: $e');
    }
  }

  /// Static singleton client for screen callers without explicit DI
  static ApiClient? _defaultClient;
  static ApiClient get defaultClient => _defaultClient ??= ApiClient(
    authTokenProvider: () async {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
      try {
        return await SecureSessionStorage.instance.getAuthToken();
      } catch (_) {}
      return null;
    },
  );

  /// Uploads 7-second Voice Spark statically from screen widgets
  static Future<Map<String, dynamic>> uploadVoiceSpark({
    required File audioFile,
    required double durationSeconds,
    required String prompt,
    ApiClient? client,
  }) async {
    final activeClient = client ?? defaultClient;
    final fileName = audioFile.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: fileName.isNotEmpty ? fileName : 'voice_spark.m4a',
      ),
      'prompt': prompt,
      'duration': durationSeconds,
    });

    final response = await activeClient.dio.post<dynamic>(
      '/api/v1/profile/voice-spark',
      data: formData,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'status': 'success'};
  }

  /// Deletes active Voice Spark statically from screen widgets
  static Future<bool> deleteVoiceSpark({ApiClient? client}) async {
    final activeClient = client ?? defaultClient;
    try {
      final response = await activeClient.dio.delete<dynamic>('/api/v1/profile/voice-spark');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('VoiceSparkService.deleteVoiceSpark error: $e');
      return false;
    }
  }

  /// Uploads 7-second Voice Spark to backend and persists Supabase Storage CDN URL
  Future<Map<String, dynamic>> uploadVoiceSparkInstance({
    required String filePath,
    required String prompt,
    double duration = 7.0,
  }) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName.isNotEmpty ? fileName : 'voice_spark.m4a',
      ),
      'prompt': prompt,
      'duration': duration,
    });

    final response = await _apiClient.dio.post<dynamic>(
      '/api/v1/profile/voice-spark',
      data: formData,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'status': 'success'};
  }

  /// Deletes active Voice Spark from profile
  Future<bool> deleteVoiceSparkInstance() async {
    try {
      final response = await _apiClient.dio.delete<dynamic>('/api/v1/profile/voice-spark');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('VoiceSparkService deleteVoiceSpark error: $e');
      return false;
    }
  }

  /// Disposes recorder resources cleanly
  void dispose() {
    _amplitudeSubscription?.cancel();
    _amplitudeController.close();
    _audioRecorder.dispose();
  }
}
