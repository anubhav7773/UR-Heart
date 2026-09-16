import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/features/auth/presentation/onboarding_screen.dart';
import 'package:ur_heart/features/home/presentation/main_shell_screen.dart';
import 'package:ur_heart/features/kyc/presentation/photo_upload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization notice: $e");
  }
  runApp(const URHeartApp());
}

class URHeartApp extends StatelessWidget {
  const URHeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UR-Heart',
      debugShowCheckedModeBanner: false,
      theme: URHeartTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: URHeartColors.canvasBackground,
              body: Center(
                child: CircularProgressIndicator(
                  color: URHeartColors.brandPrimary,
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return PhotoUploadScreen(
              onContinue: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainShellScreen()),
                );
              },
            );
          }

          return OnboardingScreen(
            onGoogleAuthSuccess: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PhotoUploadScreen(
                    onContinue: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShellScreen()),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
