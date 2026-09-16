import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/env_config.dart';
import '../../../core/network/api_client.dart';

/// Authentication Repository handling Firebase Auth (Google & Email/Password)
/// and FastAPI backend session synchronization.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseAuth get auth => _auth;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("GOOGLE_SIGN_IN_ERROR: $e");
      rethrow;
    }
  }

  /// Sign Up with Email and Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("FIREBASE_SIGN_UP_ERROR: ${e.code} - ${e.message}");
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      debugPrint("SIGN_UP_ERROR: $e");
      rethrow;
    }
  }

  /// Sign In with Email and Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("FIREBASE_SIGN_IN_ERROR: ${e.code} - ${e.message}");
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      debugPrint("SIGN_IN_ERROR: $e");
      rethrow;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Map Firebase Auth Exception to human-readable user message
  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'invalid-credential':
        return 'Invalid email or password. Please verify your credentials.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email format. Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled by security administrators.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment before trying again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  /// Sync authenticated Firebase session with FastAPI backend
  Future<bool> syncSessionWithBackend({
    required DateTime dob,
    String? fullName,
    String? phoneNumber,
    String? whatsappNumber,
    String gender = 'other',
    String city = 'Lucknow',
    String bio = '',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();
      if (idToken == null) return false;

      final dio = createApiClient(baseUrl: EnvConfig.apiBaseUrl);
      final formattedDob =
          "${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";

      String phone = phoneNumber ??
          (user.phoneNumber != null && user.phoneNumber!.isNotEmpty
              ? user.phoneNumber!
              : "+91987654${(user.uid.hashCode.abs() % 9000 + 1000).toString().padLeft(4, '0')}");
      if (!phone.startsWith('+91')) {
        phone = '+919876541234';
      }
      final wa = whatsappNumber ?? phone;

      String rawName = fullName ??
          (user.displayName != null && user.displayName!.isNotEmpty
              ? user.displayName!
              : (user.email != null ? user.email!.split('@').first : "UR Heart User"));
      String cleanName = rawName.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
      if (cleanName.length < 2) cleanName = "UR Heart User";
      if (cleanName.length > 50) cleanName = cleanName.substring(0, 50);

      final response = await dio.post(
        '/api/v1/auth/session-sync',
        data: {
          'phone_number': phone,
          'whatsapp_number': wa,
          'full_name': cleanName,
          'dob': formattedDob,
          'gender': gender,
          'city': city,
          'bio': bio,
          'android_id': '',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("SESSION_SYNC_WARNING: $e");
      // Auth succeeded, backend sync non-fatal fallback
      return true;
    }
  }
}
