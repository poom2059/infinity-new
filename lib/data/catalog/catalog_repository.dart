import 'dart:convert';

import '../../config/app_config.dart';
import '../../domain/food_ordering.dart';
import '../api/infinity_api_client.dart';

class CatalogRepository {
  CatalogRepository(this._client);

  final InfinityApiClient _client;

  Future<List<RegisteredMerchant>> fetchMerchants() async {
    if (!AppConfig.useApi) {
      return List<RegisteredMerchant>.from(kSeedMerchants);
    }
    final data = await _client.getJson('/v1/merchants') as Map<String, dynamic>;
    final list = data['merchants'] as List<dynamic>? ?? [];
    return list.map((e) => _merchantFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FoodMenuItem>> fetchMenu(String slug) async {
    if (!AppConfig.useApi) {
      for (final x in kSeedMerchants) {
        if (x.slug == slug || x.name == slug) {
          return menuForMerchant(x);
        }
      }
      return menuForMerchant(kSeedMerchants.first);
    }
    final data = await _client.getJson('/v1/merchants/${Uri.encodeComponent(slug)}/menu') as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => _itemFromJson(e as Map<String, dynamic>)).toList();
  }

  RegisteredMerchant _merchantFromJson(Map<String, dynamic> j) {
    return RegisteredMerchant(
      slug: '${j['slug'] ?? ''}',
      name: '${j['name']}',
      category: '${j['category']}',
      etaMinutes: (j['eta_minutes'] as num?)?.toInt() ?? 20,
      rating: (j['rating'] as num?)?.toDouble() ?? 4.5,
      usageCount: (j['usage_count'] as num?)?.toInt() ?? 0,
      imageUrl: '${j['image_url']}',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 2,
      deliveryFee: (j['delivery_fee'] as num?)?.toInt() ?? 0,
    );
  }

  FoodMenuItem _itemFromJson(Map<String, dynamic> j) {
    return FoodMenuItem(
      name: '${j['name']}',
      price: (j['price'] as num?)?.toInt() ?? 0,
      description: '${j['description'] ?? ''}',
      imageUrl: '${j['image_url'] ?? ''}',
      section: '${j['menu_section'] ?? ''}',
    );
  }
}

/// สำหรับส่งออเดอร์ — แปลง PlacedOrder เป็น JSON ที่เซิร์ฟเวอร์รับได้
Map<String, dynamic> placedOrderToJson(PlacedOrder o) {
  return {
    'merchant_slug': o.merchant.slug.isEmpty ? o.merchant.name : o.merchant.slug,
    'total_baht': o.totalBaht,
    'pickup_mode': o.pickupMode,
    'status': o.statusLabel,
    'lines': o.lines
        .map(
          (l) => {
            'item_name': l.itemName,
            'unit_price': l.unitPrice,
            'qty': l.qty,
          },
        )
        .toList(),
    'breakdown': {
      'phase1_minutes': o.deliveryBreakdown.phase1Minutes,
      'phase2_minutes': o.deliveryBreakdown.phase2Minutes,
      'phase3_minutes': o.deliveryBreakdown.phase3Minutes,
      'distance_km': o.deliveryBreakdown.distanceKm,
    },
  };
}

PlacedOrder placedOrderFromJson(Map<String, dynamic> j, RegisteredMerchant merchant) {
  final dynamic linesField = j['lines'] ?? j['lines_json'];
  List<dynamic> linesRaw;
  if (linesField is String) {
    try {
      linesRaw = jsonDecode(linesField) as List<dynamic>? ?? [];
    } catch (_) {
      linesRaw = [];
    }
  } else if (linesField is List<dynamic>) {
    linesRaw = linesField;
  } else {
    linesRaw = [];
  }
  final lines = linesRaw.map((e) {
    final m = e as Map<String, dynamic>;
    return OrderLine(
      itemName: '${m['item_name']}',
      unitPrice: (m['unit_price'] as num?)?.toInt() ?? 0,
      qty: (m['qty'] as num?)?.toInt() ?? 1,
    );
  }).toList();
  final dynamic b = j['breakdown'] ?? j['breakdown_json'];
  Map<String, dynamic>? bm;
  if (b is String) {
    try {
      bm = jsonDecode(b) as Map<String, dynamic>?;
    } catch (_) {
      bm = null;
    }
  } else if (b is Map<String, dynamic>) {
    bm = b;
  }
  final bool pickup = j['pickup_mode'] == true || j['pickup_mode'] == 1;
  final DeliveryPhaseBreakdown breakdown;
  if (bm != null &&
      bm['phase1_minutes'] != null &&
      bm['phase2_minutes'] != null &&
      bm['phase3_minutes'] != null) {
    final d = (bm['distance_km'] as num?)?.toDouble() ?? merchant.distanceKm;
    breakdown = DeliveryPhaseBreakdown(
      phase1Title: 'ไรเดอร์ไปถึงร้าน',
      phase1Subtitle: 'จากระยะ ~${d.toStringAsFixed(1)} กม.',
      phase1Minutes: (bm['phase1_minutes'] as num).toInt(),
      phase2Title: 'ร้านทำอาหาร',
      phase2Subtitle: 'เฟส 2',
      phase2Minutes: (bm['phase2_minutes'] as num).toInt(),
      phase3Title: 'ส่งถึงคุณ',
      phase3Subtitle: 'เฟส 3',
      phase3Minutes: (bm['phase3_minutes'] as num).toInt(),
      distanceKm: d,
    );
  } else {
    breakdown = estimateDeliveryPhases(merchant, pickupMode: pickup);
  }
  return PlacedOrder(
    id: '${j['id']}',
    placedAt: DateTime.tryParse('${j['placed_at']}') ?? DateTime.now(),
    merchant: merchant,
    lines: lines,
    totalBaht: (j['total_baht'] as num?)?.toInt() ?? 0,
    deliveryBreakdown: breakdown,
    pickupMode: pickup,
    statusLabel: '${j['status'] ?? 'กำลังจัดส่ง'}',
  );
}
