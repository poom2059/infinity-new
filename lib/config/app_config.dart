/// ค่าคอนฟิกรันไทม์
///
/// ตัวอย่าง local:
/// `--dart-define=USE_API=true --dart-define=API_BASE=http://localhost:8787`
///
/// ตัวอย่าง Cloudways (API + เว็บโดเมนเดียวกัน):
/// `--dart-define=USE_API=true --dart-define=API_BASE=`
/// หรือใส่ URL เต็ม เช่น `https://phpstack-xxxxx.cloudwaysapps.com`
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  static const bool useApi = bool.fromEnvironment('USE_API', defaultValue: false);

  static const String apiBaseFromEnv = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8787',
  );

  /// ว่างหรือ `.` = ใช้ same-origin (เหมาะกับ Cloudways ที่เสิร์ฟ API+เว็บโดเมนเดียว)
  String get apiBaseUrl {
    var s = apiBaseFromEnv.trim();
    if (s == '.' || s.toLowerCase() == 'same-origin') {
      return '';
    }
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
