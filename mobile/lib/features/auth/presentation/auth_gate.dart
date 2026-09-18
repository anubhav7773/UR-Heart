import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'onboarding_screen.dart';
import 'profile_setup_screen.dart';
import '../../kyc/presentation/photo_upload_screen.dart';
import '../../feed/presentation/main_nav_scaffold.dart';

class AuthGate extends StatelessWidget {
  final Stream<User?>? authStream;

  const AuthGate({super.key, this.authStream});

  Stream<User?> _resolveStream() {
    if (authStream != null) return authStream!;
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<Widget> _resolveInitialRoute(User firebaseUser) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      final dio = createApiClient();
      
      final response = await dio.get(
        '/api/v1/users/profile',
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final String fullName = data['full_name'] ?? '';
        final List photos = data['photos'] ?? [];
        final String kycState = data['kyc_state'] ?? 'pending_ai';
        final bool kycStatus = data['kyc_status'] ?? false;

        // 1. Incomplete Basic Profile -> Profile Setup
        if (fullName.trim().isEmpty) {
          return const ProfileSetupScreen();
        }

        // 2. Only route to Onboarding KYC if user has ZERO photos AND never submitted KYC
        if (photos.isEmpty && kycState == 'pending_ai' && !kycStatus) {
          return const PhotoUploadScreen();
        }

        // 3. User has photos or already submitted KYC -> Main Navigation Feed
        return const MainNavScaffold();
      }
    } catch (e) {
      // If 404, user record needs profile creation
      if (e is DioException && e.response?.statusCode == 404) {
        return const ProfileSetupScreen();
      }
    }
    return const MainNavScaffold();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _resolveStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0D),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2E63))),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const OnboardingScreen();
        }

        return FutureBuilder<Widget>(
          future: _resolveInitialRoute(user),
          builder: (context, routeSnapshot) {
            if (routeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0A0A0D),
                body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2E63))),
              );
            }
            return routeSnapshot.data ?? const MainNavScaffold();
          },
        );
      },
    );
  }
}
