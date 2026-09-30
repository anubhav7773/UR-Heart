import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/storage/secure_session_storage.dart';

/// Result envelope for Google Sign-In operations
class GoogleAuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;

  const GoogleAuthResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.errorMessage,
    this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
  });

  factory GoogleAuthResult.success({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
    String? idToken,
  }) =>
      GoogleAuthResult(
        isSuccess: true,
        userId: userId,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
      );

  factory GoogleAuthResult.cancelled() => const GoogleAuthResult(
        isSuccess: false,
        isCancelled: true,
      );

  factory GoogleAuthResult.failure(String message) => GoogleAuthResult(
        isSuccess: false,
        errorMessage: message,
      );
}

/// 100% Production-Grade Google Sign-In & One Tap Service
/// Seamlessly coordinates Google Identity Credential Manager, Firebase Auth,
/// and local session storage.
class GoogleAuthService {
  static const String serverClientId =
      '527791570469-hvkp9ctr4v0qnihptkq0vs080419e0cf.apps.googleusercontent.com';

  static const String keyUserId = 'ur_heart_user_id';
  static const String keyUserEmail = 'ur_heart_user_email';
  static const String keyUserName = 'ur_heart_user_name';
  static const String keyUserPhoto = 'ur_heart_user_photo';
  static const String keyAuthToken = 'ur_heart_auth_token';

  FirebaseAuth? _firebaseAuth;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  GoogleAuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth;

  FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      _firebaseAuth = FirebaseAuth.instance;
      return _firebaseAuth;
    } catch (e) {
      debugPrint(
          '[GoogleAuthService] FirebaseAuth not initialized or unavailable: $e');
      return null;
    }
  }

  /// Idempotently initializes the Google Sign In SDK with the Web Client ID
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId,
      );
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      debugPrint('[GoogleAuthService] Initialization error: $e');
      rethrow;
    }
  }

  /// Triggers the Google One Tap / Interactive Credential Flow
  Future<GoogleAuthResult> signIn() async {
    try {
      await initialize();

      // Trigger modern Credential Manager One Tap / Account Chooser
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();

      final String? idToken = account.authentication.idToken;
      final String email = account.email;
      final String? displayName = account.displayName;
      final String? photoUrl = account.photoUrl;
      String userId = account.id;

      // Authenticate with Firebase Auth if idToken is available
      if (idToken != null && idToken.isNotEmpty) {
        final auth = _auth;
        if (auth != null) {
          try {
            final OAuthCredential credential = GoogleAuthProvider.credential(
              idToken: idToken,
            );
            final UserCredential userCredential =
                await auth.signInWithCredential(credential);
            if (userCredential.user?.uid != null) {
              userId = userCredential.user!.uid;
            }
          } catch (firebaseErr) {
            debugPrint(
                '[GoogleAuthService] Firebase Auth credential sync notice: $firebaseErr');
          }
        }
      }

      // SEC-HIGH-05: Hardware-Backed Secure Session Storage Migration
      if (idToken != null) {
        await SecureSessionStorage.instance.saveAuthToken(idToken);
      }
      await SecureSessionStorage.instance.saveUserSession(
        userId: userId,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      return GoogleAuthResult.success(
        userId: userId,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
      );
    } on GoogleSignInException catch (e) {
      debugPrint(
          '[GoogleAuthService] GoogleSignInException: ${e.code} - ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return GoogleAuthResult.cancelled();
      }
      return GoogleAuthResult.failure(
        e.description ?? 'Google Sign-In was not completed. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '[GoogleAuthService] FirebaseAuthException: ${e.code} - ${e.message}');
      return GoogleAuthResult.failure(
        e.message ?? 'Authentication service error. Please try again.',
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Unexpected error: $e');
      final errorStr = e.toString();
      if (errorStr.toLowerCase().contains('cancel')) {
        return GoogleAuthResult.cancelled();
      }
      return GoogleAuthResult.failure(
        'Unable to sign in with Google. Please check your internet connection.',
      );
    }
  }

  /// Signs out from both Google Identity and Firebase Auth
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await _auth?.signOut();
    } catch (_) {}

    // SEC-HIGH-05: Atomic hardware-backed keystore session purge
    await SecureSessionStorage.instance.clearAllSessionData();
  }
}
