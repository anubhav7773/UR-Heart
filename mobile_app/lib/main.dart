import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/security/storage_manager.dart';
import 'core/services/fcm_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/onboarding_screen.dart';

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
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: webFirebaseOptions);
    } else {
      await Firebase.initializeApp();
      await MobileAds.instance.initialize();
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
      webProvider: ReCaptchaV3Provider('6LeA_sample_site_key'),
    );

    await FcmService.instance.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('Firebase / AdMob initialization notice: ${e.toString()}');
    }
  }
  runApp(const RuralHeartApp());
}

class RuralHeartApp extends StatelessWidget {
  const RuralHeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project RuralHeart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const RootSplashHandler(),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainHomeScreen()),
        );
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
