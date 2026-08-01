/// บนมือถือ/เดสก์ท็อปไม่ใช้ redirect ของเบราว์เซอร์
class WebRedirect {
  WebRedirect._();

  static String get currentUrl => '';

  static void go(String url) {}

  /// อ่าน `?auth_token=` แล้วลบออกจาก URL
  static String? takeAuthToken() => null;

  /// อ่าน `?auth_error=` แล้วลบออกจาก URL
  static String? takeAuthError() => null;
}
