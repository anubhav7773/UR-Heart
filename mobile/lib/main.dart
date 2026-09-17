import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/features/auth/presentation/auth_gate.dart';

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
      home: const AuthGate(),
    );
  }
}
