import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/features/auth/presentation/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const OnboardingScreen(),
    );
  }
}
