import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';

class ProfileRepository {
  final Dio _dio;

  ProfileRepository({Dio? dio}) : _dio = dio ?? createApiClient();

  Future<void> submitProfileSetup({
    required String fullName,
    required String whatsappNumber,
    required String gender,
    required String city,
    required String bio,
    double? latitude,
    double? longitude,
    String? detectedLocality,
  }) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("User session expired. Please re-authenticate.");
    }

    final String? idToken = await currentUser.getIdToken();

    final payload = {
      "full_name": fullName.trim(),
      "whatsapp_number": whatsappNumber.trim(),
      "gender": gender, // 'male', 'female', 'lgbtq+'
      "city": city.trim(),
      "bio": bio.trim(),
      "latitude": latitude,
      "longitude": longitude,
      "detected_locality": detectedLocality,
    };

    final response = await _dio.post(
      "/api/v1/user/profile-setup",
      data: payload,
      options: Options(
        headers: {
          "Authorization": "Bearer $idToken",
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(response.data["detail"] ?? "Failed to save profile.");
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final String? idToken = await currentUser.getIdToken();
    try {
      final response = await _dio.get(
        "/api/v1/users/me",
        options: Options(
          headers: {
            "Authorization": "Bearer $idToken",
          },
        ),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
