/// ค่าคอนฟิกรันไทม์สำหรับ production
///
/// `--dart-define=USE_API=true --dart-define=API_BASE=.`
/// `--dart-define=OMISE_PUBLIC_KEY=pkey_test_xxx`
/// `--dart-define=GOOGLE_MAPS_BROWSER_KEY=...`
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  /// Production default: ต้องใช้ API เสมอ
  static const bool useApi = bool.fromEnvironment('USE_API', defaultValue: true);

  static const String apiBaseFromEnv = String.fromEnvironment(
    'API_BASE',
    defaultValue: '',
  );

  /// ว่างหรือ `.` = same-origin
  String get apiBaseUrl {
    var s = apiBaseFromEnv.trim();
    if (s.isEmpty || s == '.' || s.toLowerCase() == 'same-origin') {
      return '';
    }
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static const String omisePublicKey = String.fromEnvironment(
    'OMISE_PUBLIC_KEY',
    defaultValue: '',
  );

  static const String googleMapsBrowserKey = String.fromEnvironment(
    'GOOGLE_MAPS_BROWSER_KEY',
    defaultValue: '',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// OAuth 2.0 Web Client ID (สำหรับ Google Sign-In บนเว็บ)
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
