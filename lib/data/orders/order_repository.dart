import '../../domain/food_ordering.dart';
import '../api/infinity_api_client.dart';
import '../catalog/catalog_repository.dart';

class OrderRepository {
  OrderRepository(this._client);

  final InfinityApiClient _client;

  Future<List<PlacedOrder>> listOrders(List<RegisteredMerchant> merchantLookup) async {
    final data = await _client.getJson('/v1/orders') as Map<String, dynamic>;
    final list = data['orders'] as List<dynamic>? ?? [];
    return list.map((e) => _parse(e as Map<String, dynamic>, merchantLookup)).toList();
  }

  Future<PlacedOrder> createOrder(PlacedOrder draft, List<RegisteredMerchant> merchantLookup) async {
    final payload = placedOrderToJson(draft);
    final res = await _client.postJson('/v1/orders', payload) as Map<String, dynamic>;
    return _parse(res, merchantLookup);
  }

  Future<void> markComplete(String orderId) async {
    await _client.postJson('/v1/orders/${Uri.encodeComponent(orderId)}/complete', {});
  }

  PlacedOrder _parse(Map<String, dynamic> j, List<RegisteredMerchant> merchants) {
    final slug = '${j['merchant_slug'] ?? ''}';
    RegisteredMerchant? m;
    for (final x in merchants) {
      if (x.slug == slug || x.name == slug) {
        m = x;
        break;
      }
    }
    m ??= merchants.isNotEmpty
        ? merchants.first
        : RegisteredMerchant(
            slug: slug,
            name: slug.isEmpty ? 'ร้านค้า' : slug,
            category: 'food',
            etaMinutes: 30,
            rating: 4.5,
            usageCount: 0,
            imageUrl: '',
            distanceKm: 2,
            deliveryFee: 0,
          );
    return placedOrderFromJson(j, m);
  }
}

/// สะพานไปยัง [OrderStore.ordersForDisplay] ใน main.dart
class OrderStoreBridge {
  static List<PlacedOrder> Function()? localOrders;
}
