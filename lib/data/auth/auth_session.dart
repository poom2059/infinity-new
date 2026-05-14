import 'package:shared_preferences/shared_preferences.dart';

const _kTokenKey = 'infinity_auth_token_v1';

/// เก็บโทเคนล็อกอิน (SharedPreferences)
class AuthSession {
  AuthSession(this._prefs);

  final SharedPreferences _prefs;

  String? _memoryToken;

  String? get tokenOrNull => _memoryToken ?? _prefs.getString(_kTokenKey);

  Future<void> setToken(String? token) async {
    _memoryToken = token;
    if (token == null || token.isEmpty) {
      await _prefs.remove(_kTokenKey);
    } else {
      await _prefs.setString(_kTokenKey, token);
    }
  }

  Future<void> clear() => setToken(null);
}
