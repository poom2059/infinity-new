/// ค่าคอนฟิกรันไทม์ — ใช้ `--dart-define=USE_API=true` และ `--dart-define=API_BASE=http://localhost:8787`
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  static const bool useApi = bool.fromEnvironment('USE_API', defaultValue: false);

  static const String apiBaseFromEnv = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8787',
  );

  String get apiBaseUrl {
    var s = apiBaseFromEnv.trim();
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// โทเคน FCM สาธิต (แทนที่ด้วย Firebase เมื่อเชื่อมจริง)
  static const String fcmDemoToken = String.fromEnvironment(
    'FCM_DEMO_TOKEN',
    defaultValue: 'demo-fcm-token',
  );
}
