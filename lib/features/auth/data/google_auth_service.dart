import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/sanctuary_notification_service.dart';
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
      if (!kIsWeb) {
        await GoogleSignIn.instance.initialize(
          serverClientId: serverClientId,
        );
      }
      _isInitialized = true;
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      _initCompleter = null;
      debugPrint('[GoogleAuthService] Initialization notice: $e');
      if (!kIsWeb) rethrow;
    }
  }

  /// Triggers the Google One Tap / Interactive Credential Flow
  Future<GoogleAuthResult> signIn() async {
    try {
      // 1. WEB PLATFORM: Use native Firebase signInWithPopup
      if (kIsWeb) {
        final auth = _auth;
        if (auth == null) {
          return GoogleAuthResult.failure(
            'Firebase Auth service is unavailable on Web. Please refresh the page.',
          );
        }

        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });

        final UserCredential userCredential =
            await auth.signInWithPopup(googleProvider);
        final User? user = userCredential.user;
        if (user == null) {
          return GoogleAuthResult.failure(
            'Unable to retrieve user details from Google sign-in.',
          );
        }

        final String? idToken = await user.getIdToken();
        final String email = user.email ?? '';
        final String? displayName = user.displayName;
        final String? photoUrl = user.photoURL;
        final String userId = user.uid;

        final cleanEmail = email.trim().toLowerCase();
        final savedRole = await SecureSessionStorage.instance.getUserRole();
        final effectiveRole = (savedRole != null && savedRole.isNotEmpty) ? savedRole : 'user';

        if (idToken != null) {
          await SecureSessionStorage.instance.saveAuthToken(idToken);
        }
        await SecureSessionStorage.instance.saveUserSession(
          userId: userId,
          email: cleanEmail,
          displayName: displayName,
          photoUrl: photoUrl,
          role: effectiveRole,
        );

        return GoogleAuthResult.success(
          userId: userId,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          idToken: idToken,
        );
      }

      // 2. MOBILE PLATFORM: Native GoogleSignIn Authenticate flow
      await initialize();

      // Trigger modern Credential Manager One Tap / Account Chooser
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();

      final String? rawGoogleIdToken = account.authentication.idToken;
      String? idToken = rawGoogleIdToken;
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
            final firebaseIdToken = await userCredential.user?.getIdToken();
            if (firebaseIdToken != null && firebaseIdToken.isNotEmpty) {
              idToken = firebaseIdToken;
            }
          } catch (firebaseErr) {
            debugPrint(
                '[GoogleAuthService] Firebase Auth credential sync notice: $firebaseErr');
          }
        }
      }

      final cleanEmail = email.trim().toLowerCase();
      final savedRole = await SecureSessionStorage.instance.getUserRole();
      final effectiveRole = (savedRole != null && savedRole.isNotEmpty) ? savedRole : 'user';

      // SEC-HIGH-05: Hardware-Backed Secure Session Storage Migration
      if (idToken != null) {
        await SecureSessionStorage.instance.saveAuthToken(idToken);
        SanctuaryNotificationService.syncStoredFcmToken(idToken);
      }
      await SecureSessionStorage.instance.saveUserSession(
        userId: userId,
        email: cleanEmail,
        displayName: displayName,
        photoUrl: photoUrl,
        role: effectiveRole,
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
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'web-context-cancelled') {
        return GoogleAuthResult.cancelled();
      }
      if (e.code == 'unauthorized-domain') {
        return GoogleAuthResult.failure(
          'Domain is not authorized in Firebase Console. Please add urheart.asiverticals.me to Authorized Domains.',
        );
      }
      return GoogleAuthResult.failure(
        e.message ?? 'Authentication service error. Please try again.',
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Unexpected error: $e');
      final errorStr = e.toString();
      if (errorStr.toLowerCase().contains('cancel') ||
          errorStr.toLowerCase().contains('popup_closed') ||
          errorStr.toLowerCase().contains('closed')) {
        return GoogleAuthResult.cancelled();
      }
      return GoogleAuthResult.failure(
        'Google Sign-In error: $e',
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
