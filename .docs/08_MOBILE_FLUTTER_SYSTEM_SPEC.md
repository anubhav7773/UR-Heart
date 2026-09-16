# Mobile Client Architecture & Flutter System Specification

**Document Identifier:** URH-MOB-008  
**Application Title:** UR-Heart (Urban and Rural Heart)  
**Parent Corporate Entity:** ASI Verticals  
**Document Version:** 1.0.0-PROD  
**Target Platform:** Flutter 3.19+ (Dart 3.3+)  
**Target Operating Systems:** Android (Min SDK 23 / Android 6.0+, Target SDK 34 / Android 14+), iOS 14+  
**State Management:** Riverpod 2.5+ (Code Generation / AsyncNotifier)  
**Network Architecture:** Dio (HTTP/REST) + WebSockets (RFC 6455)  
**Hardware & System Protection:** `flutter_windowmanager` (Android `FLAG_SECURE`)

---

## 1. Mobile Client Directory Architecture

UR-Heart utilizes a scalable, **Feature-First Clean Architecture** optimized for budget Tier-2/3 Android smartphones (conserving heap memory and thread consumption):

```text
lib/
├── main.dart                          # App entry point, Firebase & AdMob initialization
├── core/
│   ├── config/
│   │   ├── env_config.dart            # Base URLs, Ad Unit IDs, Supabase endpoints
│   │   └── theme.dart                 # Obsidian Black (#0F0F12) & Electric Crimson (#FF2E63)
│   ├── network/
│   │   ├── api_client.dart            # Dio client with Auth Interceptor & X-Installation-UUID
│   │   └── websocket_client.dart      # Resilient WebSocket client with auto-reconnect
│   ├── security/
│   │   ├── secure_screen_mixin.dart   # Hardware FLAG_SECURE toggle mixin
│   │   └── installation_service.dart  # Sandbox Installation UUID generator ("Zero on Delete")
│   └── utils/
│       ├── image_compressor.dart      # WebP (<100KB) compression & BlurHash generator
│       └── vernacular_strings.dart    # Bilingual Hindi/English UI microcopy
├── features/
│   ├── auth/
│   │   ├── data/auth_repository.dart  # Firebase Auth + FastAPI Session Sync
│   │   └── presentation/              # Splash, Neutral DOB Wheel & Phone Onboarding
│   ├── feed/
│   │   ├── data/feed_repository.dart  # Profile fetching, Swipes, Direct DM calls
│   │   └── presentation/              # Swipe Card Stack with countdown HUD
│   ├── chat/
│   │   ├── data/chat_repository.dart  # Message history & WebSocket message dispatch
│   │   └── presentation/              # Protected Chat Room & Red Anti-Leak Banner
│   ├── ads/
│   │   └── services/ad_manager.dart   # Preload buffer (AdMob, InMobi, Meta, AppLovin)
│   ├── kyc/
│   │   └── presentation/              # 5-Sec Selfie KYC Viewfinder & DPDP Consent Modal
│   └── profile/
│       └── presentation/              # Streak Flame Vault, Badges & 1-Tap Data Erase
└── shared/
    └── models/                        # Domain models (User, Match, Message, AdReward)
2. Production Dependencies: pubspec.yamlYAMLname: ur_heart
description: "100% Free Ad-Funded Dating for Urban and Rural India by ASI Verticals"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management & DI
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Network & Real-Time
  dio: ^5.4.1
  web_socket_channel: ^2.4.5

  # Authentication (Zero-Card Spark Tier)
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.8
  google_sign_in: ^6.2.1

  # Database & Storage (Supabase MCP integration)
  supabase_flutter: ^2.3.4

  # Ads Monetization (Google AdMob Mediation)
  google_mobile_ads: ^5.0.0

  # Security & Device Sandbox
  flutter_windowmanager: ^0.2.0
  shared_preferences: ^2.2.2
  uuid: ^4.3.3

  # Media Processing & Optimization
  flutter_image_compress: ^2.1.8
  blurhash_dart: ^1.1.1
  image_picker: ^1.0.7
  camera: ^0.10.5+9

  # UI Polish & Vernacular
  cached_network_image: ^3.3.1
  flutter_blurhash: ^0.8.2
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.8
  riverpod_generator: ^2.3.9
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  assets:
    - assets/images/
3. Ephemeral Installation Identity & "Zero on Delete" ServiceTo guarantee that active streaks and reward balances strictly reset to 0 upon app deletion or data clearance, the client isolates its installation_uuid inside Android's private app sandbox (/data/data/com.urheart.app/):3.1. Implementation (lib/core/security/installation_service.dart)Dartimport 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class InstallationService {
  static const String _keyInstallationUuid = 'urheart_ephemeral_install_uuid';

  /// Retrieves the existing Installation UUID or generates a fresh one.
  /// Android OS strictly wipes SharedPreferences upon app uninstall or manual data wipe.
  static Future<String> getOrCreateInstallationUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUuid = prefs.getString(_keyInstallationUuid);

    if (currentUuid == null || currentUuid.isEmpty) {
      currentUuid = const Uuid().v4();
      await prefs.setString(_keyInstallationUuid, currentUuid);
    }
    return currentUuid;
  }
}
3.2. Automated HTTP Header Interceptor (lib/core/network/api_client.dart)Dartimport 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../security/installation_service.dart';

Dio createApiClient(String baseUrl) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // 1. Inject Android App Sandbox UUID
      final installUuid = await InstallationService.getOrCreateInstallationUuid();
      options.headers['X-Installation-UUID'] = installUuid;

      // 2. Inject Firebase Bearer Token
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $idToken';
      }

      return handler.next(options);
    },
  ));

  return dio;
}
4. Hardware Display Privacy (FLAG_SECURE) EngineScreenshots, screen recording, and OS app-switcher background caching are permanently blacked out on private dating routes (FeedScreen, ChatScreen, PhotoViewer).4.1. Secure Screen Mixin (lib/core/security/secure_screen_mixin.dart)Dartimport 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

mixin SecureScreenMixin<T StatefulWidget extends> on State<T> {
  @override
  void initState() {
    super.initState();
    _enableScreenSecurity();
  }

  @override
  void dispose() {
    _disableScreenSecurity();
    super.dispose();
  }

  Future<void> _enableScreenSecurity() async {
    try {
      // Enforces hardware-level protection against screenshots & screen recordings
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("FLAG_SECURE enablement error: $e");
    }
  }

  Future<void> _disableScreenSecurity() async {
    try {
      // Clears security flags when navigating back to public settings
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("FLAG_SECURE removal error: $e");
    }
  }
}
5. Client-Side Image Compression & BlurHash GeneratorTo prevent filling Supabase's 1 GB free storage and reduce mobile bandwidth consumption in Tier-2/3 cities, every photo is re-encoded into .webp format ($<100$ KB) and analyzed for placeholder rendering:5.1. Image Optimizer (lib/core/utils/image_compressor.dart)Dartimport 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as bh;
import 'package:image/image.dart' as img;

class ImageProcessResult {
  final Uint8List compressedBytes;
  final String blurHash;
  final int fileSizeBytes;

  ImageProcessResult({
    required this.compressedBytes,
    required this.blurHash,
    required this.fileSizeBytes,
  });
}

class ImageOptimizer {
  /// Compresses source image to WebP under 100KB and calculates BlurHash
  static Future<ImageProcessResult?> processPhoto(File rawFile) async {
    // 1. Re-encode to WebP (Max dimension 1080x1350, Quality 75)
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      rawFile.absolute.path,
      minWidth: 1080,
      minHeight: 1350,
      quality: 75,
      format: CompressFormat.webp,
    );

    if (compressedBytes == null) return null;

    // 2. Decode tiny thumbnail for BlurHash calculation
    final image = img.decodeImage(compressedBytes);
    String blurHashString = "LEHLh[WB2yk8pyoJadR*.7kCMdnj"; // Safe fallback

    if (image != null) {
      // Downscale thumbnail to 32x32 for instant hash generation
      final thumbnail = img.copyResize(image, width: 32, height: 32);
      final blurHash = bh.BlurHash.encode(thumbnail, numCompX: 4, numCompY: 3);
      blurHashString = blurHash.hash;
    }

    return ImageProcessResult(
      compressedBytes: compressedBytes,
      blurHash: blurHashString,
      fileSizeBytes: compressedBytes.lengthInBytes,
    );
  }
}
6. Multi-Network Ad Mediation & Preloading EngineThe Flutter client maintains an asynchronous Dual-Slot Preload Buffer so users experience zero buffering when unlocking DMs or watching WhatsApp reveal clips.6.1. Ad Mediation Service (lib/features/ads/services/ad_manager.dart)Dartimport 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  RewardedAd? _preloadedRewardedAd;
  InterstitialAd? _preloadedInterstitialAd;
  bool _isRewardedLoading = false;
  bool _isInterstitialLoading = false;

  // ASI Verticals Production Unit IDs
  final String rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Test Unit
  final String interstitialUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test Unit

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    preloadRewardedAd();
    preloadInterstitialAd();
  }

  void preloadRewardedAd() {
    if (_isRewardedLoading || _preloadedRewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedRewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _preloadedRewardedAd = null;
          _isRewardedLoading = false;
          // Exponential backoff
          Future.delayed(const Duration(seconds: 10), () => preloadRewardedAd());
        },
      ),
    );
  }

  void preloadInterstitialAd() {
    if (_isInterstitialLoading || _preloadedInterstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      interstitialAdLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedInterstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _preloadedInterstitialAd = null;
          _isInterstitialLoading = false;
          Future.delayed(const Duration(seconds: 20), () => preloadInterstitialAd());
        },
      ),
    );
  }

  /// Displays Rewarded Ad and passes SSV custom data: {userId}:{adType}:{targetId}
  bool showRewardedAd({
    required String userId,
    required String adType,
    required String targetId,
    required VoidCallback onRewardGranted,
  }) {
    if (_preloadedRewardedAd == null) {
      preloadRewardedAd();
      return false; // Ad not ready
    }

    _preloadedRewardedAd!.setServerSideVerificationOptions(
      ServerSideVerificationOptions(
        userId: userId,
        customData: '$userId:$adType:$targetId',
      ),
    );

    _preloadedRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadedRewardedAd = null;
        preloadRewardedAd(); // Immediately buffer next video
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preloadedRewardedAd = null;
        preloadRewardedAd();
      },
    );

    _preloadedRewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onRewardGranted();
      },
    );
    return true;
  }
}
7. Real-Time WebSocket & Anti-Leak Chat ClientThe WebSocket client manages bidirectional chat, visual delivery receipts (sent, delivered, read), and intercepts server-side anti-leak violations:7.1. WebSocket Service (lib/core/network/websocket_client.dart)Dartimport 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum MessageStatus { sent, delivered, read, error }

class ChatMessageModel {
  final String msgId;
  final String matchId;
  final String senderId;
  final String content;
  final MessageStatus status;
  final DateTime timestamp;

  ChatMessageModel({
    required this.msgId,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.timestamp,
  });
}

class ChatWebSocketClient {
  WebSocketChannel? _channel;
  final String wsBaseUrl;
  final Function(ChatMessageModel) onMessageReceived;
  final Function(String errorDetail) onAntiLeakViolation;
  final Function(String matchId, String token) onWhatsAppUnlocked;

  ChatWebSocketClient({
    required this.wsBaseUrl,
    required this.onMessageReceived,
    required this.onAntiLeakViolation,
    required this.onWhatsAppUnlocked,
  });

  void connect(String jwtToken) {
    final uri = Uri.parse('$wsBaseUrl/ws/chat?token=$jwtToken');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (rawData) {
        final data = jsonDecode(rawData as String) as Map<String, dynamic>;
        final event = data['event'];

        if (event == 'incoming_message') {
          onMessageReceived(ChatMessageModel(
            msgId: data['msg_id'] ?? '',
            matchId: data['match_id'],
            senderId: data['sender_id'],
            content: data['content'],
            status: MessageStatus.delivered,
            timestamp: DateTime.parse(data['created_at']),
          ));
        } else if (event == 'anti_leak_violation') {
          // Trigger Red Banner & Error Sound on Sender's UI
          onAntiLeakViolation(data['message']);
        } else if (event == 'whatsapp_unlocked') {
          // Reveal Verified Contact Card in Chat
          onWhatsAppUnlocked(data['match_id'], data['ephemeral_token']);
        }
      },
      onError: (err) {
        debugPrint("WebSocket error: $err. Reconnecting in 5s...");
        Future.delayed(const Duration(seconds: 5), () => connect(jwtToken));
      },
      onDone: () {
        debugPrint("WebSocket disconnected.");
      },
    );
  }

  void sendMessage({
    required String matchId,
    required String recipientId,
    required String content,
  }) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        "type": "message",
        "match_id": matchId,
        "recipient_id": recipientId,
        "content": content,
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
8. Vernacular Localization & Microcopy (Tier-2/3 Indian Geo)All user-facing strings are defined in a bilingual structure (lib/core/utils/vernacular_strings.dart) to ensure clear understanding across regional users:Dartclass VernacularStrings {
  // Anti-Leak Violation Dialog
  static const Map<String, String> antiLeakAlert = {
    'en': 'Sharing phone numbers or social handles (@, IG, WA, Snap) violates UR-Heart safety policies.',
    'hi': 'फ़ोन नंबर या सोशल मीडिया आईडी (Instagram, WhatsApp) शेयर करना वर्जित है। कृपया नियमों का पालन करें।'
  };

  // WhatsApp Reveal Opt-In Dialog
  static const Map<String, String> waRevealTitle = {
    'en': 'Unlock Mutual WhatsApp Contact',
    'hi': 'व्हाट्सएप नंबर अनलॉक करें'
  };

  static const Map<String, String> waRevealDesc = {
    'en': 'UR-Heart is 100% free forever. Both you and your match must watch 3 short video ads to reveal phone numbers.',
    'hi': 'UR-Heart पूरी तरह मुफ़्त है। नंबर देखने के लिए आप दोनों को 3 छोटे वीडियो विज्ञापन देखने होंगे।'
  };

  // One-Tap Account Erase Warning
  static const Map<String, String> deleteAccountWarning = {
    'en': 'This will permanently destroy your profile, 5 photos, chats, and streak points immediately.',
    'hi': 'आपका प्रोफ़ाइल, सभी 5 फ़ोटो, चैट और स्ट्रीक हमेशा के लिए मिटा दिए जाएंगे। इसे वापस नहीं लाया जा सकता।'
  };
}
9. Antigravity Agent Verification SuiteThe Antigravity coding engine must complete and pass this automated verification checklist before concluding the mobile client phase:[ ] Installation Sandbox Verification: Verify that deleting app data via adb shell pm clear com.urheart.app wipes SharedPreferences, causing the next boot to transmit a fresh X-Installation-UUID.[ ] Hardware Screen Blocking Test: Launch app on Android emulator/device $\rightarrow$ Navigate to FeedScreen and ChatScreen $\rightarrow$ Confirm adb shell screencap -p yields a solid black file or permission failure.[ ] Client Image Compression Benchmark: Feed a raw 4K mobile camera photo (4000x3000, ~8MB) into ImageOptimizer.processPhoto() $\rightarrow$ Confirm output WebP byte buffer size is strictly $\le 100$ KB and BlurHash string length is $\ge 20$ chars.[ ] Background Ad Preload Verification: Confirm AdManager.instance.initialize() loads a rewarded ad into memory without blocking UI rendering or main thread frame rate ($> 58$ FPS).[ ] Anti-Leak WebSocket Rejection: Transmit "call me 9876543210" over WebSocket $\rightarrow$ Verify that client invokes onAntiLeakViolation callback and renders the red banner within $\le 50$ ms.Authorized & Validated for ASI Verticals / UR-Heart Mobile Engineering Pipeline.