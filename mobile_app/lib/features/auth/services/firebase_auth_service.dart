import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/security/storage_manager.dart';

/// Result object encapsulating session token, user ID, and auth status.
class AuthResult {
  final bool isSuccess;
  final String? token;
  final String? userId;
  final bool isProfileComplete;
  final String? errorMessage;

  AuthResult({
    required this.isSuccess,
    this.token,
    this.userId,
    this.isProfileComplete = false,
    this.errorMessage,
  });

  factory AuthResult.success({
    required String token,
    required String userId,
    bool isProfileComplete = false,
  }) =>
      AuthResult(
        isSuccess: true,
        token: token,
        userId: userId,
        isProfileComplete: isProfileComplete,
      );

  factory AuthResult.failure(String errorMessage) => AuthResult(
        isSuccess: false,
        errorMessage: errorMessage,
      );
}

/// Native Firebase Authentication Service for Project UR-Heart
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  String? _verificationId;
  String? get verificationId => _verificationId;

  String? _pendingPhoneNumber;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

  User? get currentUser => _firebaseAuth.currentUser;

  // ===========================================================================
  // 1. Google Sign-In Strategy
  // ===========================================================================
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google sign-in was cancelled.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult.failure('Failed to retrieve Firebase user.');
      }

      final token = await user.getIdToken() ?? '';
      await StorageManager.instance.saveAuthToken(token);
      await StorageManager.instance.saveUserId(user.uid);

      // Backend sync via ApiClient with fast fallback guard
      try {
        final res = await ApiClient.instance.firebaseLogin(
          idToken: token,
          deviceId: 'device_flutter_${DateTime.now().millisecondsSinceEpoch}',
        ).timeout(const Duration(seconds: 10));
        final data = res.data?['data'] ?? {};
        return AuthResult.success(
          token: data['access_token'] ?? token,
          userId: data['user_id'] ?? user.uid,
          isProfileComplete: data['is_profile_complete'] == true,
        );
      } catch (e) {
        if (kDebugMode) {
          print('ℹ️ [FirebaseAuthService] Backend handshake offline/slow, proceeding with Firebase session: $e');
        }
        return AuthResult.success(token: token, userId: user.uid);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FirebaseAuthService] Google Sign-In failed: $e');
      }
      return AuthResult.failure(_mapFirebaseError(e));
    }
  }

  // ===========================================================================
  // 2. Email & Password Strategy
  // ===========================================================================
  Future<AuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = userCredential.user;
      if (user == null) return AuthResult.failure('User not found.');

      final token = await user.getIdToken() ?? '';
      await StorageManager.instance.saveAuthToken(token);
      await StorageManager.instance.saveUserId(user.uid);

      // Backend Sync
      try {
        final res = await ApiClient.instance.firebaseLogin(
          idToken: token,
          deviceId: 'device_flutter_${DateTime.now().millisecondsSinceEpoch}',
        ).timeout(const Duration(seconds: 10));
        final data = res.data?['data'] ?? {};
        return AuthResult.success(
          token: data['access_token'] ?? token,
          userId: data['user_id'] ?? user.uid,
          isProfileComplete: data['is_profile_complete'] == true,
        );
      } catch (_) {
        return AuthResult.success(token: token, userId: user.uid);
      }
    } catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    }
  }

  Future<AuthResult> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = userCredential.user;
      if (user == null) return AuthResult.failure('Failed to create user account.');

      final token = await user.getIdToken() ?? '';
      await StorageManager.instance.saveAuthToken(token);
      await StorageManager.instance.saveUserId(user.uid);

      // Backend Sync
      try {
        final res = await ApiClient.instance.firebaseLogin(
          idToken: token,
          deviceId: 'device_flutter_${DateTime.now().millisecondsSinceEpoch}',
        ).timeout(const Duration(seconds: 10));
        final data = res.data?['data'] ?? {};
        return AuthResult.success(
          token: data['access_token'] ?? token,
          userId: data['user_id'] ?? user.uid,
          isProfileComplete: data['is_profile_complete'] == true,
        );
      } catch (_) {
        return AuthResult.success(token: token, userId: user.uid);
      }
    } catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    }
  }

  // ===========================================================================
  // 3. Phone & SMS OTP Strategy (Firebase verifyPhoneNumber)
  // ===========================================================================
  Future<bool> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onVerificationFailed,
  }) async {
    _pendingPhoneNumber = phoneNumber.trim();
    final completer = Completer<bool>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCred = await _firebaseAuth.signInWithCredential(credential);
            final token = await userCred.user?.getIdToken() ?? '';
            await StorageManager.instance.saveAuthToken(token);
            if (userCred.user != null) {
              await StorageManager.instance.saveUserId(userCred.user!.uid);
            }
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          final errorMsg = _mapFirebaseError(e);
          onVerificationFailed(errorMsg);
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId, resendToken);
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      onVerificationFailed(_mapFirebaseError(e));
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  Future<AuthResult> verifyPhoneOTP({
    required String otpCode,
    String? customVerificationId,
  }) async {
    final vId = customVerificationId ?? _verificationId;
    if (vId == null || vId.isEmpty) {
      // Fallback: Test/Development verifyOtp API endpoint
      try {
        final res = await ApiClient.instance.verifyOtp(
          phoneNumber: _pendingPhoneNumber ?? '+919999999999',
          otpCode: otpCode,
          deviceId: 'device_flutter_${DateTime.now().millisecondsSinceEpoch}',
        ).timeout(const Duration(seconds: 10));
        final data = res.data?['data'] ?? {};
        final token = data['access_token'] ?? 'mock_token';
        final userId = data['user_id'] ?? 'user_verified';
        await StorageManager.instance.saveAuthToken(token);
        await StorageManager.instance.saveUserId(userId);
        return AuthResult.success(
          token: token,
          userId: userId,
          isProfileComplete: data['is_profile_complete'] == true,
        );
      } catch (e) {
        return AuthResult.failure('Verification failed. Please request a new OTP code.');
      }
    }

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: otpCode.trim(),
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult.failure('Verification failed.');
      }

      final token = await user.getIdToken() ?? '';
      await StorageManager.instance.saveAuthToken(token);
      await StorageManager.instance.saveUserId(user.uid);

      try {
        final res = await ApiClient.instance.firebaseLogin(
          idToken: token,
          deviceId: 'device_flutter_${DateTime.now().millisecondsSinceEpoch}',
        ).timeout(const Duration(seconds: 10));
        final data = res.data?['data'] ?? {};
        return AuthResult.success(
          token: data['access_token'] ?? token,
          userId: data['user_id'] ?? user.uid,
          isProfileComplete: data['is_profile_complete'] == true,
        );
      } catch (_) {
        return AuthResult.success(token: token, userId: user.uid);
      }
    } catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    }
  }

  // ===========================================================================
  // 4. Sign Out & Cleanup
  // ===========================================================================
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      await StorageManager.instance.clearAuthData();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ SignOut notice: $e');
      }
    }
  }

  // ===========================================================================
  // 5. Error Mapper
  // ===========================================================================
  String _mapFirebaseError(dynamic error) {
    if (error == null) return 'An unexpected authentication error occurred.';
    final errStr = error.toString().toLowerCase();

    if (errStr.contains('user-not-found') || errStr.contains('user not found')) {
      return 'No account exists with these credentials.';
    }
    if (errStr.contains('wrong-password') || errStr.contains('invalid-credential') || errStr.contains('invalid credential')) {
      return 'Incorrect credentials. Please verify and try again.';
    }
    if (errStr.contains('email-already-in-use')) {
      return 'An account already exists with this email address.';
    }
    if (errStr.contains('invalid-verification-code') || errStr.contains('session-expired')) {
      return 'Invalid or expired OTP verification code.';
    }
    if (errStr.contains('network-request-failed') || errStr.contains('timeout')) {
      return 'Network connection error. Please check your internet.';
    }
    if (errStr.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }

    return 'Authentication failed. Please verify your credentials and try again.';
  }
}
