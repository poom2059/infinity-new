import 'package:flutter/foundation.dart';

import '../api/infinity_api_client.dart';

/// ที่อยู่ที่บันทึกพร้อมพิกัดบนแผนที่
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.detail,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String label;
  final String detail;
  final double lat;
  final double lng;

  factory SavedPlace.fromApi(Map<String, dynamic> j) {
    return SavedPlace(
      id: '${j['id']}',
      label: '${j['label'] ?? ''}',
      detail: '${j['detail'] ?? ''}',
      lat: (j['lat'] as num?)?.toDouble() ?? 13.7563,
      lng: (j['lng'] as num?)?.toDouble() ?? 100.5018,
    );
  }
}

/// ซิงก์ที่อยู่ที่บันทึกผ่าน API
class SavedPlacesStore extends ChangeNotifier {
  SavedPlacesStore(this._client);

  final InfinityApiClient _client;
  final List<SavedPlace> _items = <SavedPlace>[];

  List<SavedPlace> get items => List<SavedPlace>.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  Future<void> refresh() async {
    final data = await _client.getJson('/v1/saved-places') as Map<String, dynamic>;
    final list = data['places'] as List<dynamic>? ?? [];
    _items
      ..clear()
      ..addAll(list.map((e) => SavedPlace.fromApi(e as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> add(SavedPlace place) async {
    await _client.postJson('/v1/saved-places', {
      'label': place.label,
      'detail': place.detail,
      'lat': place.lat,
      'lng': place.lng,
    });
    await refresh();
  }

  Future<void> update(SavedPlace place) async {
    await remove(place.id);
    await add(place);
  }

  Future<void> remove(String id) async {
    await _client.deleteJson('/v1/saved-places/$id');
    await refresh();
  }
}
