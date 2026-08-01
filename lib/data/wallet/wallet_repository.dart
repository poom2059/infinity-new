import '../api/infinity_api_client.dart';

class WalletBalance {
  const WalletBalance({
    required this.balanceBaht,
    required this.points,
  });

  final double balanceBaht;
  final int points;

  factory WalletBalance.fromJson(Map<String, dynamic> j) {
    return WalletBalance(
      balanceBaht: (j['balance_baht'] as num?)?.toDouble() ?? 0,
      points: (j['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.title,
    required this.amountBaht,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amountBaht;
  final String createdAt;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) {
    return LedgerEntry(
      id: '${j['id']}',
      title: '${j['title']}',
      amountBaht: (j['amount_baht'] as num?)?.toDouble() ?? 0,
      createdAt: '${j['created_at']}',
    );
  }
}

class WalletRepository {
  WalletRepository(this._client);

  final InfinityApiClient _client;

  Future<WalletBalance> balance() async {
    final data = await _client.getJson('/v1/wallet') as Map<String, dynamic>;
    return WalletBalance.fromJson(data);
  }

  Future<List<LedgerEntry>> ledger() async {
    final data = await _client.getJson('/v1/wallet/ledger') as Map<String, dynamic>;
    final list = data['entries'] as List<dynamic>? ?? [];
    return list.map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}
