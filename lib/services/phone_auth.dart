import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../firebase_options.dart';

/// Firebase Phone Auth เมื่อตั้งค่า dart-define ครบ มิฉะนั้นคืน null ให้ไปใช้ OTP ฝั่งเซิร์ฟเวอร์
class PhoneAuthService {
  PhoneAuthService._();
  static final PhoneAuthService instance = PhoneAuthService._();

  bool get firebaseReady => DefaultFirebaseOptions.isConfigured;

  String? _verificationId;

  Future<void> requestOtp(String phoneE164) async {
    if (!firebaseReady) {
      throw StateError('Firebase ยังไม่ได้ตั้งค่า');
    }
    final completer = Completer<void>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (_) {
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      timeout: const Duration(seconds: 90),
    );
    await completer.future;
  }

  Future<String> confirmOtp(String smsCode) async {
    final vid = _verificationId;
    if (vid == null || vid.isEmpty) {
      throw StateError('ยังไม่ได้ขอรหัสจาก Firebase');
    }
    final cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: smsCode);
    final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
    final token = await userCred.user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('ไม่ได้รับ Firebase idToken');
    }
    return token;
  }

  /// แปลงเบอร์ไทย 0xxxxxxxxx → +66xxxxxxxxx
  static String toE164(String raw) {
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('66')) return '+$p';
    if (p.startsWith('0')) return '+66${p.substring(1)}';
    if (p.startsWith('+')) return raw.trim();
    return '+$p';
  }
}
