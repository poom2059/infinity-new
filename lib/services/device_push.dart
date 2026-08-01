import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../firebase_options.dart';

/// โทเคนอุปกรณ์สำหรับลงทะเบียนกับเซิร์ฟเวอร์ (FCM เมื่อตั้งค่า Firebase แล้ว)
class DevicePush {
  DevicePush._();
  static final DevicePush instance = DevicePush._();

  Future<String?> getToken() async {
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_push_id');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('device_push_id', id);
    }
    return 'device:$id';
  }
}
