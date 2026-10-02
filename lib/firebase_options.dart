import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for UR-Heart production sanctuary.
/// Generated from google-services.json and Firebase project configuration.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBlKy9rPprSKhrrMuXZLppiupVOV8Fr5W0',
    appId: '1:527791570469:web:527791570469',
    messagingSenderId: '527791570469',
    projectId: 'ur-heart-44b46',
    authDomain: 'ur-heart-44b46.firebaseapp.com',
    storageBucket: 'ur-heart-44b46.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBlKy9rPprSKhrrMuXZLppiupVOV8Fr5W0',
    appId: '1:527791570469:android:75f37d7112f67e7f5c09cc',
    messagingSenderId: '527791570469',
    projectId: 'ur-heart-44b46',
    storageBucket: 'ur-heart-44b46.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBlKy9rPprSKhrrMuXZLppiupVOV8Fr5W0',
    appId: '1:527791570469:ios:75f37d7112f67e7f5c09cc',
    messagingSenderId: '527791570469',
    projectId: 'ur-heart-44b46',
    storageBucket: 'ur-heart-44b46.firebasestorage.app',
    iosBundleId: 'com.urheart.app',
  );
}
