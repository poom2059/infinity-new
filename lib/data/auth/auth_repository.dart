import '../api/api_exception.dart';
import '../api/infinity_api_client.dart';
import 'auth_session.dart';
import 'auth_user.dart';

class AuthRepository {
  AuthRepository(this._client, this._session);

  final InfinityApiClient _client;
  final AuthSession _session;

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final data = await _client.postJson('/v1/auth/request-otp', {'phone': phone}, auth: false);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<AuthUser> verifyOtp({required String phone, required String code}) async {
    final data = await _client.postJson(
      '/v1/auth/verify-otp',
      {'phone': phone, 'code': code},
      auth: false,
    ) as Map<String, dynamic>;
    return _persist(data);
  }

  /// ผู้ให้บริการโซเชียลที่เซิร์ฟเวอร์เปิดใช้งานแล้ว: provider -> start URL
  Future<Map<String, String>> socialProviders() async {
    final data = await _client.getJson('/v1/auth/providers', auth: false) as Map<String, dynamic>;
    final list = data['providers'] as List<dynamic>? ?? const [];
    final out = <String, String>{};
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final startUrl = '${m['start_url'] ?? ''}';
      if (startUrl.isNotEmpty) {
        out['${m['provider']}'] = startUrl;
      }
    }
    return out;
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
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _session.setCachedUser(user);
    return user;
  }

  Future<AuthUser?> fetchMe() async {
    final t = _session.tokenOrNull;
    if (t == null || t.isEmpty) {
      return null;
    }
    try {
      final data = await _client.getJson('/v1/me') as Map<String, dynamic>;
      final user = AuthUser.fromJson(data as Map<String, dynamic>);
      await _session.setCachedUser(user);
      return user;
    } on ApiException catch (e) {
      // 401 จริง = โทเคนใช้ไม่ได้ ถึงจะออกจากระบบ ส่วนเน็ตหลุด/เซิร์ฟเวอร์หลับให้ใช้สแนปชอตเดิม
      if (e.statusCode == 401) {
        final token = _session.tokenOrNull ?? '';
        if (token.split('.').length == 3) {
          return _session.cachedUser;
        }
        await _session.clear();
        return null;
      }
      return _session.cachedUser;
    } catch (_) {
      return _session.cachedUser;
    }
  }

  Future<AuthUser> updateProfile({
    String? name,
    String? phone,
    String? avatarUrl,
    String? avatarFrame,
  }) async {
    final data = await _client.patchJson('/v1/me', {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (avatarFrame != null) 'avatar_frame': avatarFrame,
    }) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data);
    await _session.setCachedUser(user);
    return user;
  }

  Future<void> logout() => _session.clear();
}
