// เลือก implementation ตามแพลตฟอร์ม:
//  - เว็บ  : ใช้ Google Maps JS SDK (google_geo_service_web.dart)
//  - มือถือ: ใช้ Google REST API ผ่าน http (google_geo_service_io.dart)
import 'google_geo_service_io.dart'
    if (dart.library.js_interop) 'google_geo_service_web.dart';

/// รายการแนะนำสถานที่จาก Google Places Autocomplete
class GeoSuggestion {
  const GeoSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
}

/// ผลลัพธ์พิกัด + ที่อยู่จาก Google Geocoder
class GeoResult {
  const GeoResult({required this.lat, required this.lng, required this.address});

  final double lat;
  final double lng;
  final String address;
}

/// บริการแผนที่ของ Google (Places Autocomplete + Geocoding)
///
/// ใช้ผ่าน factory `GoogleGeoService()` ซึ่งจะเลือก implementation
/// ที่เหมาะกับแพลตฟอร์มให้อัตโนมัติ
abstract class GoogleGeoService {
  factory GoogleGeoService() => createService();

  /// ค้นหารายการสถานที่แนะนำขณะพิมพ์ (จำกัดเฉพาะประเทศไทย)
  Future<List<GeoSuggestion>> autocomplete(String input);

  /// แปลง placeId เป็นพิกัด + ที่อยู่เต็ม
  Future<GeoResult?> geocodePlaceId(String placeId);

  /// แปลงพิกัดเป็นที่อยู่ (reverse geocoding)
  Future<String?> reverseGeocode(double lat, double lng);
}
