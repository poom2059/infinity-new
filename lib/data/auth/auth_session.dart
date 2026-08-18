import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_user.dart';

const _kTokenKey = 'infinity_auth_token_v1';
const _kUserKey = 'infinity_auth_user_v1';

/// เก็บโทเคนล็อกอินและสแนปชอตผู้ใช้ไว้ในเครื่อง เพื่อให้รีเฟรชแล้วยังล็อกอินอยู่
class AuthSession {
  AuthSession(this._prefs) {
    _memoryToken = _prefs.getString(_kTokenKey);
    _memoryUser = _readCachedUser();
  }

  final SharedPreferences _prefs;

  String? _memoryToken;
  AuthUser? _memoryUser;

  String? get tokenOrNull => _memoryToken ?? _prefs.getString(_kTokenKey);

  AuthUser? get cachedUser => _memoryUser ?? _readCachedUser();

  AuthUser? _readCachedUser() {
    final raw = _prefs.getString(_kUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setToken(String? token) async {
    _memoryToken = token;
    if (token == null || token.isEmpty) {
      await _prefs.remove(_kTokenKey);
      await setCachedUser(null);
    } else {
      await _prefs.setString(_kTokenKey, token);
    }
  }

  Future<void> setCachedUser(AuthUser? user) async {
    _memoryUser = user;
    if (user == null) {
      await _prefs.remove(_kUserKey);
    } else {
      await _prefs.setString(_kUserKey, jsonEncode(user.toJson()));
    }
  }

  Future<void> clear() async {
    _memoryToken = null;
    _memoryUser = null;
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kUserKey);
  }
}
