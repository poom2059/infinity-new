import 'dart:js_interop';

import 'package:google_maps/google_maps.dart' as gmaps;
import 'package:google_maps/google_maps_geocoding.dart' as gmaps;
import 'package:google_maps/google_maps_places.dart' as gmp;

import 'google_geo_service.dart';

GoogleGeoService createService() => GoogleGeoServiceWeb();

/// บริการแผนที่ของ Google สำหรับ "เว็บ" — เรียก Maps JS SDK โดยตรง (ไม่ติด CORS)
class GoogleGeoServiceWeb implements GoogleGeoService {
  @override
  Future<List<GeoSuggestion>> autocomplete(String input) async {
    if (input.trim().isEmpty) {
      return const <GeoSuggestion>[];
    }
    try {
      final gmp.AutocompleteService service = gmp.AutocompleteService();
      final gmp.AutocompleteResponse res = await service.getPlacePredictions(
        gmp.AutocompletionRequest(
          input: input,
          language: 'th',
          componentRestrictions: gmp.ComponentRestrictions(country: 'th'.toJS),
        ),
      );
      return res.predictions.map((gmp.AutocompletePrediction p) {
        final gmp.StructuredFormatting sf = p.structuredFormatting;
        return GeoSuggestion(
          placeId: p.placeId,
          mainText: sf.mainText,
          secondaryText: sf.secondaryText,
        );
      }).toList();
    } catch (_) {
      return const <GeoSuggestion>[];
    }
  }

  @override
  Future<GeoResult?> geocodePlaceId(String placeId) async {
    try {
      final gmaps.Geocoder geocoder = gmaps.Geocoder();
      final gmaps.GeocoderResponse res = await geocoder.geocode(
        gmaps.GeocoderRequest(placeId: placeId, language: 'th'),
      );
      if (res.results.isEmpty) {
        return null;
      }
      final gmaps.GeocoderResult r = res.results.first;
      final gmaps.LatLng loc = r.geometry.location;
      return GeoResult(
        lat: loc.lat.toDouble(),
        lng: loc.lng.toDouble(),
        address: r.formattedAddress,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final gmaps.Geocoder geocoder = gmaps.Geocoder();
      final gmaps.GeocoderResponse res = await geocoder.geocode(
        gmaps.GeocoderRequest(location: gmaps.LatLng(lat, lng), language: 'th'),
      );
      if (res.results.isEmpty) {
        return null;
      }
      return res.results.first.formattedAddress;
    } catch (_) {
      return null;
    }
  }
}
