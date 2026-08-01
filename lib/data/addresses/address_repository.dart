import '../api/infinity_api_client.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.detail,
  });

  final String id;
  final String label;
  final String detail;

  factory SavedAddress.fromJson(Map<String, dynamic> j) {
    return SavedAddress(
      id: '${j['id']}',
      label: '${j['label']}',
      detail: '${j['detail']}',
    );
  }
}

class AddressRepository {
  AddressRepository(this._client);

  final InfinityApiClient _client;

  Future<List<SavedAddress>> list() async {
    final data = await _client.getJson('/v1/addresses') as Map<String, dynamic>;
    final list = data['addresses'] as List<dynamic>? ?? [];
    return list.map((e) => SavedAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SavedAddress> create({required String label, required String detail}) async {
    final data = await _client.postJson('/v1/addresses', {'label': label, 'detail': detail}) as Map<String, dynamic>;
    return SavedAddress.fromJson(data);
  }
}
