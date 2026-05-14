import '../../config/app_config.dart';
import '../api/infinity_api_client.dart';

class GeocodeResult {
  const GeocodeResult({
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String label;
  final double lat;
  final double lng;

  factory GeocodeResult.fromJson(Map<String, dynamic> j) {
    return GeocodeResult(
      label: '${j['label']}',
      lat: (j['lat'] as num?)?.toDouble() ?? 13.7563,
      lng: (j['lng'] as num?)?.toDouble() ?? 100.5018,
    );
  }
}

/// Geocoding สาธิต — เชื่อม Google/Mapbox เมื่อมี API key จริง
class MapsRepository {
  MapsRepository(this._client);

  final InfinityApiClient _client;

  Future<GeocodeResult> geocode(String query) async {
    if (!AppConfig.useApi) {
      return GeocodeResult(label: '$query (ออฟไลน์)', lat: 13.7563, lng: 100.5018);
    }
    final data = await _client.getJson('/v1/maps/geocode?q=${Uri.encodeQueryComponent(query)}') as Map<String, dynamic>;
    return GeocodeResult.fromJson(data);
  }
}
