import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../security/storage_manager.dart';
import '../utils/image_compressor.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  late final Dio dio;

  // Base URL configuration for Render production deployment
  static String get defaultBaseUrl => 'https://ur-heart.onrender.com/api/v1';
  static String get baseUrl => defaultBaseUrl;
  String get currentBaseUrl => dio.options.baseUrl;

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
    String? receiverId,
    String? matchId,
    String? message,
  }) async {
    return await dio.post('/intent/send-chai-invite', data: {
      if (receiverId != null) 'receiver_id': receiverId,
      if (matchId != null) 'match_id': matchId,
      if (message != null) 'message': message,
    });
  }

  // 10. Check Safe WhatsApp Bridge Unlocking Status (15 mutual messages threshold)
  Future<Response> getWhatsAppBridgeStatus({
    required String matchId,
  }) async {
    return await dio.get('/chat/whatsapp-bridge-status/$matchId');
  }

  // 10b. Submit WhatsApp Contact Sharing Consent Handshake
  Future<Response> giveWhatsAppConsent({
    required String matchId,
  }) async {
    return await dio.post('/chat/whatsapp-consent/$matchId');
  }

  // 10c. Submit Two-Way Consent for WhatsApp & Live Route on Google Maps
  Future<Response> submitChatConsent({
    required String matchId,
    required bool shareWhatsapp,
    required bool shareLocation,
  }) async {
    return await dio.post('/chat/consent/$matchId', data: {
      'share_whatsapp': shareWhatsapp,
      'share_location': shareLocation,
    });
  }

  // 10d. Get Two-Way Consent Status for WhatsApp & Location
  Future<Response> getChatConsent({
    required String matchId,
  }) async {
    return await dio.get('/chat/consent/$matchId');
  }

  // 10e. Get Safe Bridge Status (15-message milestone, dual consent, dual ₹499 payment)
  Future<Response> getBridgeStatus(String matchId) async {
    return await dio.get('/chat/bridge-status/$matchId');
  }

  // 10f. Submit Safe Bridge ₹499 Unlock Payment
  Future<Response> submitBridgePayment({
    required String matchId,
    required String paymentId,
    double amount = 499.0,
  }) async {
    return await dio.post('/chat/bridge/unlock-payment', data: {
      'match_id': matchId,
      'payment_id': paymentId,
      'amount': amount,
    });
  }

  // 10g. Submit / Update Mutual Meetup Consent
  Future<Response> updateMeetupConsent({
    required String matchId,
    required bool agree,
  }) async {
    return await dio.post('/chat/$matchId/meetup-consent', data: {
      'agree': agree,
    });
  }

  // 10h. Get Nearby Date Spots (Chai, Cafes, Restaurants, Hotels) with Midpoint support
  Future<Response> getMeetupSpots({
    double? lat,
    double? lon,
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
    int? radiusMeters,
    String? category,
  }) async {
    final Map<String, dynamic> query = {};
    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      query['lat1'] = lat1;
      query['lon1'] = lon1;
      query['lat2'] = lat2;
      query['lon2'] = lon2;
    } else if (lat != null && lon != null) {
      query['lat'] = lat;
      query['lon'] = lon;
    } else {
      query['lat'] = 28.6139;
      query['lon'] = 77.2090;
    }

    if (radiusMeters != null) {
      query['radius_meters'] = radiusMeters;
    }
    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }
    return await dio.get('/places/meetup-spots', queryParameters: query);
  }

  // 10i. Unsend Chat Message (Delete for Everyone)
  Future<Response> unsendMessage({
    required String messageId,
  }) async {
    return await dio.delete('/chat/messages/$messageId');
  }

  // 10j. Profile Visitors & Ghost Passers (Who Passed You)
  Future<Response> getVisitors({
    int limit = 20,
    int offset = 0,
  }) async {
    return await dio.get('/profile/visitors', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
  }

  Future<Response> dismissVisitor({
    required String visitorId,
  }) async {
    return await dio.delete('/profile/visitors/$visitorId');
  }

  // 10k. Direct DM Sachet Unlock (₹49)
  Future<Response> unlockDirectDMSachet({
    required String targetUserId,
  }) async {
    return await dio.post('/payments/sachet/direct-dm', data: {
      'target_user_id': targetUserId,
    });
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

  // 12c. Claim Rewarded Ad Bonus (Swipes or Temporary Photo Pass)
  Future<Response> claimAdReward({
    required String rewardType,
  }) async {
    return await dio.post('/ads/claim-reward', data: {
      'reward_type': rewardType,
    });
  }

  // 12d. Fetch Active Pass & Super Boost Status
  Future<Response> getActivePassStatus() async {
    return await dio.get('/payments/active-pass');
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

  // 16b. Mark Messages as Read (Double Blue Ticks)
  Future<Response> markMessagesAsRead(String matchId) async {
    return await dio.post('/chat/$matchId/read');
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
    final XFile compressedXFile = await ImageCompressor.compressImage(XFile(filePath));
    final String uploadPath = compressedXFile.path;
    final fileName = uploadPath.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(uploadPath, filename: fileName),
    });
    return await dio.post('/profile/photos', data: formData);
  }

  // 20c. Upload 15-Second Voice Bio (Audio Intro)
  Future<Response> uploadVoiceBio(List<int> bytes, String fileName, {int durationSeconds = 15}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return await dio.post(
      '/profile/upload-voice-bio',
      queryParameters: {'duration_seconds': durationSeconds},
      data: formData,
    );
  }

  // 20d. Upload Voice Bio via Local File Path
  Future<Response> uploadVoiceBioFile(String filePath, {int durationSeconds = 15}) async {
    final fileName = filePath.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return await dio.post(
      '/profile/upload-voice-bio',
      queryParameters: {'duration_seconds': durationSeconds},
      data: formData,
    );
  }

  // 20e. Delete Voice Bio
  Future<Response> deleteVoiceBio() async {
    return await dio.delete('/profile/voice-bio');
  }

  // 20f. Get Conversational Icebreakers
  Future<Response> getIcebreakers() async {
    return await dio.get('/chat/icebreakers');
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

  Future<Response> getConversations() async {
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
  Future<Response> postSendChaiInvite({
    String? receiverId,
    String? matchId,
    String? message,
  }) async {
    return await dio.post('/intent/send-chai-invite', data: {
      if (receiverId != null) 'receiver_id': receiverId,
      if (matchId != null) 'match_id': matchId,
      if (message != null) 'message': message,
    });
  }

  // 28. Get Profile
  Future<Response> getProfile({String? userId}) async {
    return await dio.get('/profile', queryParameters: userId != null ? {'user_id': userId} : null);
  }

  // 29. Get App Version & OTA Auto-Update Config
  Future<Response> getAppVersion() async {
    return await dio.get('/system/app-version');
  }

  // 30. Send Direct DM (POST /feed/direct-dm)
  Future<Response> sendDirectDm({
    required String targetUserId,
    required String message,
  }) async {
    return await dio.post('/feed/direct-dm', data: {
      'target_user_id': targetUserId,
      'message': message,
    });
  }
}
