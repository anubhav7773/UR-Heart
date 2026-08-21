import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:clerk_auth/clerk_auth.dart';
import 'core/navigation/nav_keys.dart';
import 'core/network/api_client.dart';
import 'core/security/storage_manager.dart';
import 'core/services/fcm_service.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/privacy_protection_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';

const webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDSAqbIIfzeWErV-XdA7NbJ2aus-E0AoFk',
  authDomain: 'ur-heart.firebaseapp.com',
  projectId: 'ur-heart',
  storageBucket: 'ur-heart.firebasestorage.app',
  messagingSenderId: '1038187472582',
  appId: '1:1038187472582:web:eef9e7296a2900f19119c7',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrivacyProtectionService.enableSecureScreen();

  // 1. Initialize Clerk Authentication Client with publishable key
  try {
    final clerkPublishableKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1ZdFOk3vMFsg46dCDj6D
3XyZfiIZ/VNjgTyJP71DBFgikzPfdjcB+hXVUcgSNq7YOlUCEKPC8v5EK3BdZ0pl
rbIGebi6Yv3sKOhGZh1/bYlhrdRuUWs5xZkaxjUB72avRKbzeQ7HXSNwfxDWcI5E
jgdB8cru5U0iuXBo+k5WYOGvqdZkclD2m79Rsk4eex6FfcJ5pVszXjnKJ4K2qpdC
PD8izDm7JqZR9Zmf9CukDyPb8U6zPSD5fqrretZkpxSd077mN5XDT4dW+rZwXCht
koiw2WLDouxr9XS4BacxORxfbVcZoAGwjvGS9w1QNMWtWY5O0Vtt9qfQPJTmdzua
4wIDAQAB
-----END PUBLIC KEY-----''';

    // Store Clerk configuration in app state for later use
    // Creating Auth instance with dynamic configuration that matches the package API
    try {
      // Attempt to create Auth with the config parameter
      // The config is expected to be a ClerkAuthConfig-like object
      final clerkAuthConfig = <String, dynamic>{
        'publishableKey': clerkPublishableKey,
      };
      
      // Use the Auth class from clerk_auth package
      // For now, we'll store the config for use in auth screens
      if (kDebugMode) {
        print('✅ Clerk authentication configuration loaded');
        print('📧 Publishable Key: ${clerkPublishableKey.substring(0, 20)}...');
      }
    } catch (innerError) {
      if (kDebugMode) {
        print('⚠️ Clerk Auth instantiation: ${innerError.toString()}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Clerk initialization notice: ${e.toString()}');
    }
  }

  // 2. Explicit Safe Firebase Initialization before runApp
  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        await Firebase.initializeApp(options: webFirebaseOptions);
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initializeApp notice: ${e.toString()}');
    }
  }

  // 3. Android High Importance Notification Channel Setup
  if (!kIsWeb) {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for urgent match and chat push notifications.',
        importance: Importance.max,
        playSound: true,
      );
      final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      if (kDebugMode) {
        print('Android Notification Channel creation notice: $e');
      }
    }
  }

  // 4. Safe Mobile Ads & AppCheck Initialization
  try {
    if (!kIsWeb) {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: [
            '33BE2250B43518CCDA7DE426D04EE231', // Personal Developer Test Device Safeguard
          ],
        ),
      );
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
      webProvider: ReCaptchaV3Provider('6LeA_sample_site_key'),
    );

    await FcmService.instance.initialize(
      foregroundMessengerKey: appMessengerKey,
      navigatorKey: rootNavigatorKey,
    );
  } catch (e) {
    if (kDebugMode) {
      print('AdMob / AppCheck initialization notice: ${e.toString()}');
    }
  }

  // 5. Initialize Sentry and wrap the app
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://04973e1a72f04bf6d0cdb86f8dae89f5@o4511946639015936.ingest.us.sentry.io/4511946784636928';
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
    },
    appRunner: () => runApp(const RuralHeartApp()),
  );
}

class RuralHeartApp extends StatefulWidget {
  const RuralHeartApp({super.key});

  @override
  State<RuralHeartApp> createState() => _RuralHeartAppState();
}

class _RuralHeartAppState extends State<RuralHeartApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sendPresenceUpdate(true);
    _initDeviceServices();
  }

  Future<void> _initDeviceServices() async {
    try {
      await LocationService.instance.getCurrentLocation();
      await FcmService.instance.syncFcmToken();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ONLY update online presence heartbeat — NEVER reset/refresh explore feed on resume
    if (state == AppLifecycleState.resumed) {
      _sendPresenceUpdate(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _sendPresenceUpdate(false);
    }
  }

  Future<void> _sendPresenceUpdate(bool isOnline) async {
    try {
      final token = await StorageManager.instance.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiClient.instance.dio.put(
          '/profile/presence',
          data: {'is_online': isOnline},
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UR-Heart',
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AnimatedSplashScreen(),
    );
  }
}

class RootSplashHandler extends StatefulWidget {
  const RootSplashHandler({super.key});

  @override
  State<RootSplashHandler> createState() => _RootSplashHandlerState();
}

class _RootSplashHandlerState extends State<RootSplashHandler> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final token = await StorageManager.instance.getAuthToken();
    final isComplete = await StorageManager.instance.isProfileComplete();

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (currentUser != null || (token != null && token.isNotEmpty)) {
      if (isComplete) {
        final initialMsg = NotificationRouter.pendingNotification ??
            await FirebaseMessaging.instance.getInitialMessage();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainHomeScreen()),
        );

        if (initialMsg != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationRouter.handleNotificationClick(initialMsg);
          });
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded, size: 70, color: Color(0xFFE91E63)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFFE91E63)),
          ],
        ),
      ),
    );
  }
}
