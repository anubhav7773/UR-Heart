import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';

class ProfileService {
  final Dio _dio;

  ProfileService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Helper to fetch fresh Firebase ID Token or stored auth token.
  Future<String?> _getAuthToken() async {
    try {
      final String? freshToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (freshToken != null && freshToken.isNotEmpty) {
        return freshToken;
      }
    } catch (_) {}
    return await StorageManager.instance.getAuthToken();
  }

  /// Uploads profile photo to FastAPI backend (`POST /api/v1/profile/photos`)
  /// using Dio and FormData.fromMap with MultipartFile.fromFile.
  /// Automatically passes `Authorization: Bearer <firebase_id_token>` header.
  Future<String?> uploadProfilePhoto(File imageFile) async {
    final token = await _getAuthToken();
    final fileName = imageFile.path.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
    });

    final options = Options(
      headers: {
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    );

    final response = await _dio.post(
      '/profile/photos',
      data: formData,
      options: options,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('photo_url') && data['photo_url'] != null) {
          return data['photo_url'] as String;
        } else if (data['data'] != null && data['data']['photo_url'] != null) {
          return data['data']['photo_url'] as String;
        }
      }
    }
    return null;
  }

  /// Fetches logged-in user profile details (`GET /api/v1/profile`)
  Future<Map<String, dynamic>?> getUserProfile() async {
    final token = await _getAuthToken();
    final options = Options(
      headers: {
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    );

    final response = await _dio.get(
      '/profile',
      options: options,
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        return data['data'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Updates profile metadata in FastAPI backend (`PUT /api/v1/profile`)
  /// Automatically passes `Authorization: Bearer <firebase_id_token>` header.
  Future<Response> updateProfile(Map<String, dynamic> payload) async {
    final token = await _getAuthToken();
    final options = Options(
      headers: {
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    );

    return await _dio.put(
      '/profile',
      data: payload,
      options: options,
    );
  }
}
