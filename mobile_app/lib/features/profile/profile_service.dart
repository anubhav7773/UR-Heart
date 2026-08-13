import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';

class ProfileService {
  final Dio _dio;

  ProfileService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// Uploads profile photo to FastAPI backend (`POST /api/v1/profile/photos`)
  /// using Dio and FormData.fromMap with MultipartFile.fromFile.
  /// Automatically passes `Authorization: Bearer <firebase_id_token>` header.
  Future<String?> uploadProfilePhoto(File imageFile) async {
    final token = await StorageManager.instance.getAuthToken();
    final fileName = imageFile.path.split('/').last;
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

  /// Updates profile metadata in FastAPI backend (`PUT /api/v1/profile`)
  /// Automatically passes `Authorization: Bearer <firebase_id_token>` header.
  Future<Response> updateProfile(Map<String, dynamic> payload) async {
    final token = await StorageManager.instance.getAuthToken();
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
