import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/widgets/app_logo.dart';
import '../home/home_screen.dart';
import '../profile/onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  bool _isEmailMode = false;
  bool _isSignUpMode = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSuccessLogin(Map<String, dynamic> data) async {
    final token = data['access_token'] as String;
    final userId = data['user_id'] as String;
    final bool isComplete = data['is_profile_complete'] ?? false;
    final bool isPremium = data['is_premium'] ?? false;

    // Clear previous cached session before saving new user credentials
    await StorageManager.instance.clearAll();

    await StorageManager.instance.saveAuthToken(token);
    await StorageManager.instance.saveUserId(userId);
    await StorageManager.instance.setProfileComplete(isComplete);
    await StorageManager.instance.setPremiumStatus(isPremium);

    if (!mounted) return;

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
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '1038187472582-o6jseecrlmr46v5ovm7v6icn5l8vju7e.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sign-In was cancelled by user.'),
              backgroundColor: Colors.orangeAccent,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (kDebugMode) {
        print('[Google OAuth] Selected Account Email: ${googleUser.email}');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase Initialization Safeguard
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final String? idToken = await userCredential.user?.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Auth failed to yield ID Token.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      final response = await ApiClient.instance.firebaseLogin(
        idToken: idToken,
        deviceId: 'flutter_native_android',
      );

      final data = response.data['data'];
      if (data != null) {
        await _handleSuccessLogin(data);
      } else {
        final errMsg = response.data['detail'] ?? response.data['message'] ?? 'Backend response returned null data envelope.';
        throw Exception(errMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailPasswordAuth() async {
    if (!_formKey.currentState!.validate()) return;

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String fullName = _nameController.text.trim();

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;
      if (_isSignUpMode) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final String? idToken = await userCredential.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Firebase authentication failed to generate ID token.');
      }

      dynamic response;
      if (_isSignUpMode) {
        response = await ApiClient.instance.emailSignup(
          idToken: idToken,
          fullName: fullName.isNotEmpty ? fullName : email.split('@')[0],
          deviceId: 'flutter_native_android',
        );
      } else {
        response = await ApiClient.instance.emailLoginToken(
          idToken: idToken,
          deviceId: 'flutter_native_android',
        );
      }

      final data = response.data['data'];
      if (data != null) {
        await _handleSuccessLogin(data);
      } else {
        final errMsg = response.data['detail'] ?? response.data['message'] ?? 'Backend returned empty envelope.';
        throw Exception(errMsg);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? 'Authentication failed.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered. Please login instead.';
      } else if (e.code == 'wrong-password' || e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password should be at least 6 characters long.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auth Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // App Branding Header
              const Center(
                child: AppLogo(size: 80, showGlow: true),
              ),
              const SizedBox(height: 16),
              const Text(
                'UR Heart',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "UR Heart • India's Most Honest & Affordable Dating App",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.amber, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),

              // Auth Mode Toggle Tabs (Google vs Email/Password)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEmailMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isEmailMode ? const Color(0xFFE91E63) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Google Sign-In',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isEmailMode ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEmailMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isEmailMode ? const Color(0xFFE91E63) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Email / Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isEmailMode ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Color(0xFFE91E63)),
                  ),
                )
              else if (!_isEmailMode) ...[
                // Google Sign-In Card
                ElevatedButton(
                  onPressed: _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.g_mobiledata,
                          size: 34,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Email / Password Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isSignUpMode) ...[
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.person, color: Color(0xFFE91E63)),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (val) {
                            if (_isSignUpMode && (val == null || val.trim().isEmpty)) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.email, color: Color(0xFFE91E63)),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(val.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFFE91E63)),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleEmailPasswordAuth,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        child: Text(
                          _isSignUpMode ? 'Create Account' : 'Sign In',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUpMode = !_isSignUpMode;
                          });
                        },
                        child: Text(
                          _isSignUpMode
                              ? 'Already have an account? Login'
                              : 'Don\'t have an account? Sign Up',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Text(
                "By signing in, you agree to UR Heart's Terms of Service & Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
