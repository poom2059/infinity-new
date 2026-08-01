import 'package:web/web.dart' as web;

/// ช่วยทำ OAuth redirect บนเว็บ และดึงโทเคนที่เซิร์ฟเวอร์ส่งกลับมาทาง query
class WebRedirect {
  WebRedirect._();

  static String get currentUrl => web.window.location.href;

  static void go(String url) {
    web.window.location.assign(url);
  }

  static String? takeAuthToken() => _takeParam('auth_token');

  static String? takeAuthError() => _takeParam('auth_error');

  static String? _takeParam(String name) {
    final uri = Uri.parse(web.window.location.href);
    final value = uri.queryParameters[name];
    if (value == null || value.isEmpty) return null;
    final params = Map<String, String>.from(uri.queryParameters)..remove(name);
    final cleaned = uri.replace(queryParameters: params.isEmpty ? null : params);
    web.window.history.replaceState(null, '', cleaned.toString());
    return value;
  }
}
