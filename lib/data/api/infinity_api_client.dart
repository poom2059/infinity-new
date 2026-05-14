import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'api_exception.dart';

typedef TokenGetter = Future<String?> Function();

/// HTTP client พร้อม Bearer และ JSON
class InfinityApiClient {
  InfinityApiClient({
    required this.tokenGetter,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final TokenGetter tokenGetter;
  final http.Client _http;

  Uri _u(String path) {
    final base = AppConfig.instance.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await tokenGetter();
      if (t != null && t.isNotEmpty) {
        h['Authorization'] = 'Bearer $t';
      }
    }
    return h;
  }

  Future<dynamic> getJson(String path, {bool auth = true}) async {
    final res = await _http.get(_u(path), headers: await _headers(auth: auth));
    return _decode(res);
  }

  Future<dynamic> postJson(String path, Object? body, {bool auth = true}) async {
    final res = await _http.post(
      _u(path),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patchJson(String path, Object? body, {bool auth = true}) async {
    final res = await _http.patch(
      _u(path),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> deleteJson(String path, {bool auth = true}) async {
    final res = await _http.delete(
      _u(path),
      headers: await _headers(auth: auth),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final code = res.statusCode;
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (code >= 200 && code < 300) {
      return data;
    }
    final String msg;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        msg = '${map['error']}';
      } else {
        msg = res.body.isNotEmpty ? res.body : 'คำขอไม่สำเร็จ';
      }
    } else {
      final body = res.body;
      if (body.contains('<!DOCTYPE') || body.contains('<html')) {
        msg = code == 404
            ? 'ไม่พบ API นี้บนเซิร์ฟเวอร์ (ลองรีสตาร์ท npm start ในโฟลเดอร์ server)'
            : 'เซิร์ฟเวอร์ตอบกลับผิดรูปแบบ (HTTP $code)';
      } else {
        msg = body.isNotEmpty ? body : 'คำขอไม่สำเร็จ';
      }
    }
    throw ApiException(msg, statusCode: code);
  }

  void close() => _http.close();
}
