import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'google_geo_service.dart';

GoogleGeoService createService() => GoogleGeoServiceIo();

/// บริการแผนที่ของ Google สำหรับ "มือถือ/เดสก์ท็อป" — เรียก Web Service REST
///
/// บนมือถือไม่ติดปัญหา CORS จึงเรียก endpoint ของ Google ได้โดยตรง
/// คีย์จาก `--dart-define=GOOGLE_MAPS_BROWSER_KEY=...`
class GoogleGeoServiceIo implements GoogleGeoService {
  static String get _apiKey => AppConfig.googleMapsBrowserKey;

  @override
  Future<List<GeoSuggestion>> autocomplete(String input) async {
    if (input.trim().isEmpty || _apiKey.isEmpty) {
      return const <GeoSuggestion>[];
    }
    try {
      final Uri url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeQueryComponent(input)}'
        '&language=th&components=country:th&key=$_apiKey',
      );
      final http.Response res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return const <GeoSuggestion>[];
      }
      final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> predictions = (data['predictions'] as List<dynamic>?) ?? <dynamic>[];
      return predictions.map((dynamic e) {
        final Map<String, dynamic> p = e as Map<String, dynamic>;
        final Map<String, dynamic> sf =
            (p['structured_formatting'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        return GeoSuggestion(
          placeId: (p['place_id'] as String?) ?? '',
          mainText: (sf['main_text'] as String?) ?? (p['description'] as String? ?? ''),
          secondaryText: (sf['secondary_text'] as String?) ?? '',
        );
      }).where((GeoSuggestion s) => s.placeId.isNotEmpty).toList();
    } catch (_) {
      return const <GeoSuggestion>[];
    }
  }

  @override
  Future<GeoResult?> geocodePlaceId(String placeId) async {
    if (_apiKey.isEmpty) return null;
    try {
      final Uri url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?place_id=${Uri.encodeQueryComponent(placeId)}&language=th&key=$_apiKey',
      );
      final http.Response res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> results = (data['results'] as List<dynamic>?) ?? <dynamic>[];
      if (results.isEmpty) {
        return null;
      }
      final Map<String, dynamic> r = results.first as Map<String, dynamic>;
      final Map<String, dynamic> loc =
          (r['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      return GeoResult(
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
        address: (r['formatted_address'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    if (_apiKey.isEmpty) return null;
    try {
      final Uri url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&language=th&key=$_apiKey',
      );
      final http.Response res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> results = (data['results'] as List<dynamic>?) ?? <dynamic>[];
      if (results.isEmpty) {
        return null;
      }
      final Map<String, dynamic> r = results.first as Map<String, dynamic>;
      return r['formatted_address'] as String?;
    } catch (_) {
      return null;
    }
  }
}
