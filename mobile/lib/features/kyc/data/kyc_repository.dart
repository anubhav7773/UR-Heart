import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';

class KycRepository {
  final Dio _client;

  KycRepository({Dio? client})
      : _client = client ?? createApiClient(baseUrl: EnvConfig.apiBaseUrl);

  /// Scans image file against Tesseract OCR and anti-leak detection
  Future<Map<String, dynamic>> scanPhoto(File imageFile) async {
    try {
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _client.post(
        '/api/v1/moderation/scan-photo',
        data: formData,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('KycRepository.scanPhoto DioException: ${e.response?.data}');
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        throw Exception(e.response?.data['detail']);
      }
      throw Exception('Photo scan failed: ${e.message}');
    }
  }

  /// Submits 5-second video KYC to Groq AI verification pipeline
  Future<Map<String, dynamic>> submitKycVideo({
    required File videoFile,
    String? userName,
    String? userCity,
  }) async {
    try {
      final fileName = videoFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          videoFile.path,
          filename: fileName,
        ),
        if (userName != null) 'user_name': userName,
        if (userCity != null) 'user_city': userCity,
      });

      final response = await _client.post(
        '/api/v1/kyc/submit-video',
        data: formData,
        options: Options(
          headers: {
            'X-Consent-DPDP': 'true',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('KycRepository.submitKycVideo DioException: ${e.response?.data}');
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        throw Exception(e.response?.data['detail']);
      }
      throw Exception('Video KYC submission failed: ${e.message}');
    }
  }
}
