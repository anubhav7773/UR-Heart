import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/core/network/clerk_auth_interceptor.dart';
import 'package:ruralheart_mobile/core/network/environment_config.dart';
import 'package:ruralheart_mobile/core/network/secure_api_client.dart';
import 'package:ruralheart_mobile/core/network/user_repository.dart';

void main() {
  group('EnvironmentConfig Tests', () {
    test('Environment base URLs resolve accurately', () {
      EnvironmentConfig.setEnvironment(Environment.production);
      expect(EnvironmentConfig.baseUrl, equals('https://ur-heart.onrender.com/api/v1'));

      EnvironmentConfig.setEnvironment(Environment.staging);
      expect(EnvironmentConfig.baseUrl, equals('https://staging.ur-heart.com/api/v1'));

      EnvironmentConfig.setCustomBaseUrl('https://custom-api.ruralheart.com/api/v1');
      expect(EnvironmentConfig.baseUrl, equals('https://custom-api.ruralheart.com/api/v1'));

      // Reset
      EnvironmentConfig.setEnvironment(Environment.development);
    });

    test('WebSocket URLs match HTTP scheme correctly', () {
      EnvironmentConfig.setEnvironment(Environment.production);
      expect(EnvironmentConfig.wsBaseUrl.startsWith('wss://'), isTrue);

      EnvironmentConfig.setCustomBaseUrl('http://10.0.2.2:8000/api/v1');
      expect(EnvironmentConfig.wsBaseUrl, equals('ws://10.0.2.2:8000'));
    });
  });

  group('UserProfileModel & UserRepository Serialization Tests', () {
    final mockMeResponse = {
      "success": true,
      "message": "User profile retrieved successfully.",
      "data": {
        "id": "11111111-2222-3333-4444-555555555555",
        "user_id": "11111111-2222-3333-4444-555555555555",
        "clerk_id": "user_2XyzTest123",
        "email": "priya.sharma@example.com",
        "phone_number": "+919876543210",
        "full_name": "Priya Sharma",
        "first_name": "Priya",
        "age": 24,
        "dob": "2000-01-01",
        "bio": "Exploring life in Ayodhya.",
        "area_name": "Ayodhya",
        "village_pin_code": "224001",
        "gender": "female",
        "interested_in": "male",
        "intent": "serious",
        "photos": ["https://r2.ruralheart.com/p1.webp"],
        "photo_url": "https://r2.ruralheart.com/p1.webp",
        "is_verified": true,
        "is_admin": false,
        "is_online": true,
        "is_onboarded": true
      }
    };

    test('UserProfileModel parses backend JSON payload correctly', () {
      final user = UserProfileModel.fromJson(mockMeResponse['data'] as Map<String, dynamic>);
      expect(user.id, equals('11111111-2222-3333-4444-555555555555'));
      expect(user.clerkId, equals('user_2XyzTest123'));
      expect(user.email, equals('priya.sharma@example.com'));
      expect(user.fullName, equals('Priya Sharma'));
      expect(user.firstName, equals('Priya'));
      expect(user.age, equals(24));
      expect(user.isVerified, isTrue);
      expect(user.isOnboarded, isTrue);
      expect(user.photos.length, equals(1));
    });
  });
}
