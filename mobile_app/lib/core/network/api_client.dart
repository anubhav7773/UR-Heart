import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../security/storage_manager.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  late final Dio dio;

  // Base URL configuration for Render production deployment
  static String get defaultBaseUrl => 'https://ur-heart.onrender.com/api/v1';

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Dynamic Auth Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageManager.instance.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          if (kDebugMode) {
            print('API Error [${error.response?.statusCode}]: ${error.response?.data}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // 1. Social OAuth Login (Google / Meta)
  Future<Response> socialLogin({
    required String provider,
    required String idToken,
    required String deviceId,
    String? fcmToken,
  }) async {
    return await dio.post('/auth/social-login', data: {
      'provider': provider,
      'id_token': idToken,
      'device_id': deviceId,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
  }

  // 1b. Firebase Authentication Token Login
  Future<Response> firebaseLogin({
    required String idToken,
    required String deviceId,
    String? fcmToken,
  }) async {
    return await dio.post('/auth/firebase-login', data: {
      'id_token': idToken,
      'device_id': deviceId,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
  }

  // 2. Send Mobile Phone OTP Code
  Future<Response> sendOtp({
    required String phoneNumber,
  }) async {
    return await dio.post('/auth/send-otp', data: {
      'phone_number': phoneNumber,
    });
  }

  // 3. Verify Mobile Phone OTP Code
  Future<Response> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    required String deviceId,
    String? fcmToken,
  }) async {
    return await dio.post('/auth/verify-otp', data: {
      'phone_number': phoneNumber,
      'otp_code': otpCode,
      'device_id': deviceId,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
  }

  // 1c. Email/Password Firebase Signup
  Future<Response> emailSignup({
    required String idToken,
    required String fullName,
    required String deviceId,
    String? fcmToken,
  }) async {
    return await dio.post('/auth/email-signup', data: {
      'id_token': idToken,
      'full_name': fullName,
      'device_id': deviceId,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
  }

  // 1d. Email/Password Firebase Login
  Future<Response> emailLoginToken({
    required String idToken,
    required String deviceId,
    String? fcmToken,
  }) async {
    return await dio.post('/auth/email-login', data: {
      'id_token': idToken,
      'device_id': deviceId,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
  }

  // 4. Email & Password Direct Fallback
  Future<Response> emailLogin({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    return await dio.post('/auth/email-login', data: {
      'email': email,
      'password': password,
      'device_id': deviceId,
    });
  }

  // 5. Upload Profile Photo to Supabase Storage
  Future<Response> uploadPhoto(List<int> bytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return await dio.post('/profile/upload-photo', data: formData);
  }

  // 6. Complete Profile Onboarding
  Future<Response> completeProfile(Map<String, dynamic> payload) async {
    return await dio.post('/profile/complete', data: payload);
  }

  // 6. Fetch Discovery Feed Deck
  Future<Response> getFeed({int limit = 10}) async {
    return await dio.get('/feed', queryParameters: {'limit': limit});
  }

  // 7. Ingest Swipe Action (reject/like/dm)
  Future<Response> postSwipe({
    required String targetUserId,
    required String action,
  }) async {
    return await dio.post('/feed/swipe', data: {
      'target_user_id': targetUserId,
      'action': action,
    });
  }

  // 8. Set Active Chai Status
  Future<Response> setChaiStatus({
    bool isFreeForChai = true,
    String statusBadge = '☕ Free for Chai',
    String? locationLandmark,
  }) async {
    return await dio.post('/intent/chai-status', data: {
      'is_free_for_chai': isFreeForChai,
      'status_badge': statusBadge,
      if (locationLandmark != null) 'location_landmark': locationLandmark,
    });
  }

  // 9. Send ₹9 Chai Invite
  Future<Response> sendChaiInvite({
    required String receiverId,
  }) async {
    return await dio.post('/intent/send-chai-invite', data: {
      'receiver_id': receiverId,
    });
  }

  // 10. Check Safe WhatsApp Bridge Unlocking Status (15 mutual messages threshold)
  Future<Response> getWhatsAppBridgeStatus({
    required String matchId,
  }) async {
    return await dio.get('/chat/whatsapp-bridge-status/$matchId');
  }

  // 11. Remote Ad Configuration
  Future<Response> getAdConfig() async {
    return await dio.get('/ads/config');
  }

  // 12. Log Ad Impression & Revenue Event
  Future<Response> logAdEvent({
    required String adUnitType,
    required String eventType,
    String networkProvider = 'AdMob',
    double ecpmEstimate = 0.0,
  }) async {
    return await dio.post('/ads/log-event', data: {
      'ad_unit_type': adUnitType,
      'event_type': eventType,
      'network_provider': networkProvider,
      'ecpm_estimate': ecpmEstimate,
    });
  }

  // 12b. Log Ad Telemetry Event (Impressions / Clicks)
  Future<Response> logAdTelemetry({
    required String adUnitId,
    required String eventType,
    String format = 'native_card',
  }) async {
    return await dio.post('/ads/telemetry', data: {
      'ad_unit_id': adUnitId,
      'ad_unit_type': format,
      'event_type': eventType,
    });
  }

  // 13. Create Razorpay Subscription Order (₹99/mo)
  Future<Response> createRazorpayOrder() async {
    return await dio.post('/payments/create-order');
  }

  // 14. Create Sachet Micro-Transaction Order (₹9, ₹19, ₹99)
  Future<Response> createSachetOrder({
    required String planType,
  }) async {
    return await dio.post('/payments/create-sachet-order', data: {
      'plan_type': planType,
    });
  }

  // 15. Fetch Active User Matches
  Future<Response> getMatches() async {
    return await dio.get('/chat/matches');
  }

  // 16. Fetch Chat Message History for Match
  Future<Response> getMessages(String matchId) async {
    return await dio.get('/chat/messages/$matchId');
  }

  // 17. Send Chat Message (Text / Media)
  Future<Response> sendMessage({
    required String matchId,
    String? clientMsgId,
    String? content,
    String? mediaUrl,
    String mediaType = 'text',
  }) async {
    return await dio.post('/chat/send', data: {
      'match_id': matchId,
      if (clientMsgId != null) 'client_msg_id': clientMsgId,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      'media_type': mediaType,
    });
  }

  // 18. Upload Chat Media Attachment to Supabase Storage 'chat-media'
  Future<Response> uploadChatMedia(List<int> bytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return await dio.post('/chat/upload-media', data: formData);
  }

  // 19. Complete Profile (PUT /profile)
  Future<Response> putProfile(Map<String, dynamic> payload) async {
    return await dio.put('/profile', data: payload);
  }

  // 20. Upload Profile Photo (POST /profile/photos)
  Future<Response> uploadProfilePhotoAlt(List<int> bytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return await dio.post('/profile/photos', data: formData);
  }

  // 20b. Upload Profile Photo via Local File Path
  Future<Response> uploadProfilePhotoFile(String filePath) async {
    final fileName = filePath.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return await dio.post('/profile/photos', data: formData);
  }

  // 21. Matches Feed (GET /matches/feed)
  Future<Response> getMatchesFeed({
    int limit = 10,
    double radiusKm = 50.0,
    String? genderPreference,
    int? minAge,
    int? maxAge,
    double? maxDistanceKm,
    double? lat,
    double? lng,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'radius_km': maxDistanceKm ?? radiusKm,
      if (genderPreference != null) 'gender_preference': genderPreference,
      if (minAge != null) 'min_age': minAge,
      if (maxAge != null) 'max_age': maxAge,
      if (maxDistanceKm != null) 'max_distance_km': maxDistanceKm,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    return await dio.get('/feed', queryParameters: query);
  }

  // 22. Matches Swipe (POST /matches/swipe)
  Future<Response> postMatchesSwipe({
    required String targetUserId,
    required String action,
  }) async {
    return await dio.post('/feed/swipe', data: {
      'target_user_id': targetUserId,
      'action': action,
    });
  }

  // 23. Chat Conversations (GET /chat/conversations)
  Future<Response> getChatConversations() async {
    return await dio.get('/chat/conversations');
  }

  // 24. Block User (POST /safety/block)
  Future<Response> blockUser({required String blockedUserId}) async {
    return await dio.post('/safety/block', data: {
      'blocked_user_id': blockedUserId,
    });
  }

  // 25. Report User (POST /safety/report)
  Future<Response> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    return await dio.post('/safety/report', data: {
      'reported_user_id': reportedUserId,
      'reason': reason,
      if (details != null) 'details': details,
    });
  }

  // 26. Verify Razorpay Payment (POST /payments/verify)
  Future<Response> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    String? planType,
  }) async {
    return await dio.post('/payments/verify', data: {
      'razorpay_payment_id': paymentId,
      'razorpay_order_id': orderId,
      'razorpay_signature': signature,
      if (planType != null) 'plan_type': planType,
    });
  }

  // 27. Send Chai Invite (POST /intent/send-chai-invite)
  Future<Response> postSendChaiInvite({required String receiverId}) async {
    return await dio.post('/intent/send-chai-invite', data: {
      'receiver_id': receiverId,
    });
  }

  // 28. Get Profile
  Future<Response> getProfile({String? userId}) async {
    return await dio.get('/profile', queryParameters: userId != null ? {'user_id': userId} : null);
  }
}
