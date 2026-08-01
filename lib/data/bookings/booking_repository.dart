import '../api/infinity_api_client.dart';

class BookingRepository {
  BookingRepository(this._client);
  final InfinityApiClient _client;

  Future<Map<String, dynamic>> create({
    required String kind,
    Map<String, dynamic> payload = const {},
  }) async {
    final data = await _client.postJson('/v1/bookings', {
      'kind': kind,
      'payload': payload,
    }) as Map<String, dynamic>;
    return data;
  }

  Future<List<Map<String, dynamic>>> list() async {
    final data = await _client.getJson('/v1/bookings') as Map<String, dynamic>;
    final list = data['bookings'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
