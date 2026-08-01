import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// ค่า Firebase จาก `--dart-define=FIREBASE_*`
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static bool get isConfigured {
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    return projectId.isNotEmpty && apiKey.isNotEmpty && appId.isNotEmpty;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      );

  static FirebaseOptions get android {
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    return FirebaseOptions(
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      appId: androidAppId.isNotEmpty ? androidAppId : appId,
      messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
  }

  static FirebaseOptions get ios {
    const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    return FirebaseOptions(
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      appId: iosAppId.isNotEmpty ? iosAppId : appId,
      messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.infinity.app'),
    );
  }
}
