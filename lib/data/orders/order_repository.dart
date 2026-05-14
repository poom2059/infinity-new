import '../../config/app_config.dart';
import '../../domain/food_ordering.dart';
import '../api/infinity_api_client.dart';
import '../catalog/catalog_repository.dart';

class OrderRepository {
  OrderRepository(this._client);

  final InfinityApiClient _client;

  Future<List<PlacedOrder>> listOrders(List<RegisteredMerchant> merchantLookup) async {
    if (!AppConfig.useApi) {
      final fn = OrderStoreBridge.localOrders;
      return fn != null ? fn() : <PlacedOrder>[];
    }
    final data = await _client.getJson('/v1/orders') as Map<String, dynamic>;
    final list = data['orders'] as List<dynamic>? ?? [];
    return list.map((e) => _parse(e as Map<String, dynamic>, merchantLookup)).toList();
  }

  Future<PlacedOrder> createOrder(PlacedOrder draft, List<RegisteredMerchant> merchantLookup) async {
    if (!AppConfig.useApi) {
      return draft;
    }
    final payload = placedOrderToJson(draft);
    final res = await _client.postJson('/v1/orders', payload) as Map<String, dynamic>;
    return _parse(res, merchantLookup);
  }

  Future<void> markComplete(String orderId) async {
    if (!AppConfig.useApi) {
      return;
    }
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
    m ??= kSeedMerchants.isNotEmpty ? kSeedMerchants.first : merchants.first;
    return placedOrderFromJson(j, m);
  }
}

/// สะพานไปยัง [OrderStore.ordersForDisplay] ใน main.dart
class OrderStoreBridge {
  static List<PlacedOrder> Function()? localOrders;
}
