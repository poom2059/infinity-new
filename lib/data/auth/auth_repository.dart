import '../api/api_exception.dart';
import '../api/infinity_api_client.dart';
import 'auth_session.dart';
import 'auth_user.dart';

class AuthRepository {
  AuthRepository(this._client, this._session);

  final InfinityApiClient _client;
  final AuthSession _session;

  Future<void> requestOtp(String phone) async {
    await _client.postJson('/v1/auth/request-otp', {'phone': phone}, auth: false);
  }

  Future<AuthUser> verifyOtp({required String phone, required String code}) async {
    final data = await _client.postJson(
      '/v1/auth/verify-otp',
      {'phone': phone, 'code': code},
      auth: false,
    ) as Map<String, dynamic>;
    return _persist(data);
  }

  Future<AuthUser> loginWithFirebaseIdToken(String idToken) async {
    final data = await _client.postJson(
      '/v1/auth/firebase',
      {'id_token': idToken},
      auth: false,
    ) as Map<String, dynamic>;
    return _persist(data);
  }

  Future<AuthUser> loginWithSocial(
    String provider, {
    String? idToken,
    String? accessToken,
  }) async {
    final data = await _client.postJson(
      '/v1/auth/social',
      {
        'provider': provider,
        if (idToken != null) 'id_token': idToken,
        if (accessToken != null) 'access_token': accessToken,
      },
      auth: false,
    ) as Map<String, dynamic>;
    return _persist(data);
  }

  Future<AuthUser> _persist(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('ไม่พบโทเค็นเข้าสู่ระบบ');
    }
    await _session.setToken(token);
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser?> fetchMe() async {
    final t = _session.tokenOrNull;
    if (t == null || t.isEmpty) {
      return null;
    }
    try {
      final data = await _client.getJson('/v1/me') as Map<String, dynamic>;
      return AuthUser.fromJson(data);
    } on ApiException {
      await _session.clear();
      return null;
    }
  }

  Future<AuthUser> updateProfile({String? name}) async {
    final data = await _client.patchJson('/v1/me', {if (name != null) 'name': name}) as Map<String, dynamic>;
    return AuthUser.fromJson(data);
  }

  Future<void> logout() => _session.clear();
}
