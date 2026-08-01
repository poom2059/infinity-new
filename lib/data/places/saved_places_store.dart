import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'detail': detail,
        'lat': lat,
        'lng': lng,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> j) {
    return SavedPlace(
      id: '${j['id']}',
      label: '${j['label'] ?? ''}',
      detail: '${j['detail'] ?? ''}',
      lat: (j['lat'] as num?)?.toDouble() ?? 13.7563,
      lng: (j['lng'] as num?)?.toDouble() ?? 100.5018,
    );
  }
}

/// เก็บรายการที่อยู่ที่บันทึก (ปักหมุดบนแผนที่) และบันทึกถาวรด้วย [SharedPreferences]
class SavedPlacesStore extends ChangeNotifier {
  SavedPlacesStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const String _kKey = 'saved_places_v1';
  static const String _kSeeded = 'saved_places_seeded_v1';

  final List<SavedPlace> _items = <SavedPlace>[];

  List<SavedPlace> get items => List<SavedPlace>.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  void _load() {
    final String? raw = _prefs.getString(_kKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(list.map((dynamic e) => SavedPlace.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        _items.clear();
      }
    }
    if (_prefs.getBool(_kSeeded) != true) {
      _seed();
      _prefs.setBool(_kSeeded, true);
      _persist();
    }
  }

  void _seed() {
    _items.addAll(const <SavedPlace>[
      SavedPlace(
        id: 'home-seed',
        label: 'บ้าน',
        detail: 'ถนนสุขุมวิท กรุงเทพฯ',
        lat: 13.7398,
        lng: 100.5602,
      ),
      SavedPlace(
        id: 'work-seed',
        label: 'ที่ทำงาน',
        detail: 'อาคารสำนักงาน สาทร กรุงเทพฯ',
        lat: 13.7236,
        lng: 100.5283,
      ),
    ]);
  }

  Future<void> add(SavedPlace place) async {
    _items.add(place);
    await _persist();
    notifyListeners();
  }

  Future<void> update(SavedPlace place) async {
    final int i = _items.indexWhere((SavedPlace e) => e.id == place.id);
    if (i >= 0) {
      _items[i] = place;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((SavedPlace e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(_kKey, jsonEncode(_items.map((SavedPlace e) => e.toJson()).toList()));
  }
}
