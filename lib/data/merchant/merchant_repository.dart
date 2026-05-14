import '../api/api_exception.dart';
import '../api/infinity_api_client.dart';

class MerchantRepository {
  MerchantRepository(this._client);

  final InfinityApiClient _client;

  Future<List<Map<String, dynamic>>> recentOrders() async {
    final data = await _client.getJson('/v1/merchant/orders') as Map<String, dynamic>;
    final list = data['orders'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// คืน null ถ้ายังไม่มีใบสมัคร หรือ API เก่าไม่มี route (404) — ไม่ให้หน้าลงทะเบียนพัง
  Future<Map<String, dynamic>?> myLatestApplication() async {
    try {
      final data = await _client.getJson('/v1/merchant/my-application') as Map<String, dynamic>;
      final raw = data['application'];
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw as Map);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitApplication({
    required String shopName,
    required String category,
    required String proposedSlug,
    String notes = '',
  }) async {
    final data = await _client.postJson(
      '/v1/merchant/applications',
      {
        'shop_name': shopName,
        'category': category,
        'proposed_slug': proposedSlug,
        'notes': notes,
      },
    ) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['application'] as Map);
  }

  Future<Map<String, dynamic>> fetchMyMenu() async {
    final data = await _client.getJson('/v1/merchant/my-menu') as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return {
      'merchant': data['merchant'] != null ? Map<String, dynamic>.from(data['merchant'] as Map) : null,
      'items': rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    };
  }

  Future<Map<String, dynamic>> createMenuItem({
    required String name,
    required int price,
    String description = '',
    String? imageUrl,
    String menuSection = 'อื่นๆ',
  }) async {
    final data = await _client.postJson(
      '/v1/merchant/menu-items',
      {
        'name': name,
        'price': price,
        'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'menu_section': menuSection,
      },
    ) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateMenuItem(
    String id, {
    String? name,
    int? price,
    String? description,
    String? imageUrl,
    bool clearImage = false,
    String? menuSection,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (price != null) body['price'] = price;
    if (description != null) body['description'] = description;
    if (menuSection != null) body['menu_section'] = menuSection;
    if (clearImage) {
      body['image_url'] = null;
    } else if (imageUrl != null) {
      body['image_url'] = imageUrl;
    }
    final data = await _client.patchJson('/v1/merchant/menu-items/${Uri.encodeComponent(id)}', body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteMenuItem(String id) async {
    await _client.deleteJson('/v1/merchant/menu-items/${Uri.encodeComponent(id)}');
  }
}
