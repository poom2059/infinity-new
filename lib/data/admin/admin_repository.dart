import '../api/infinity_api_client.dart';

class AdminRepository {
  AdminRepository(this._client);

  final InfinityApiClient _client;

  Future<List<Map<String, dynamic>>> pendingMerchants() async {
    final data = await _client.getJson('/v1/admin/pending-merchants') as Map<String, dynamic>;
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> pendingMerchantApplications() async {
    final data = await _client.getJson('/v1/admin/merchant-applications') as Map<String, dynamic>;
    final list = data['applications'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> approveMerchantApplication(String id) async {
    await _client.postJson('/v1/admin/merchant-applications/$id/approve', <String, dynamic>{});
  }

  Future<void> rejectMerchantApplication(String id) async {
    await _client.postJson('/v1/admin/merchant-applications/$id/reject', <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final data = await _client.getJson('/v1/admin/users') as Map<String, dynamic>;
    final list = data['users'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> updateUser(String id, {String? role, String? name}) async {
    await _client.patchJson('/v1/admin/users/$id', {
      if (role != null) 'role': role,
      if (name != null) 'name': name,
    });
  }

  Future<void> approveMerchantRecord(String merchantId) async {
    await _client.postJson('/v1/admin/merchants/$merchantId/approve', <String, dynamic>{});
  }
}
