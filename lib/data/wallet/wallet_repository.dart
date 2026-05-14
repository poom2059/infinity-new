import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
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
  WalletRepository(this._client, this._prefs);

  final InfinityApiClient _client;
  final SharedPreferences _prefs;

  static const String _kLinkedBank = 'wallet_demo_linked_bank_id';
  static const String _kBalance = 'wallet_demo_balance_baht';

  static const double _defaultDemoBalance = 500.80;

  /// แอปธนาคารที่ผู้ใช้เลือกเชื่อม (โหมดสาธิต — เก็บใน SharedPreferences)
  Future<String?> linkedBankAppId() async {
    if (AppConfig.useApi) {
      return null;
    }
    return _prefs.getString(_kLinkedBank);
  }

  Future<void> setLinkedBankAppId(String? id) async {
    if (AppConfig.useApi) {
      return;
    }
    if (id == null || id.isEmpty) {
      await _prefs.remove(_kLinkedBank);
    } else {
      await _prefs.setString(_kLinkedBank, id);
    }
  }

  /// บวกยอดวอเลตหลังชำระสำเร็จ (สาธิตเท่านั้น — โหมด API ให้อัปเดตจาก webhook)
  Future<void> applyDemoTopUp(double additionalBaht) async {
    if (AppConfig.useApi) {
      return;
    }
    final cur = _prefs.getDouble(_kBalance) ?? _defaultDemoBalance;
    await _prefs.setDouble(_kBalance, cur + additionalBaht);
  }

  Future<WalletBalance> balance() async {
    if (!AppConfig.useApi) {
      final stored = _prefs.getDouble(_kBalance);
      final bal = stored ?? _defaultDemoBalance;
      return WalletBalance(balanceBaht: bal, points: 3800);
    }
    final data = await _client.getJson('/v1/wallet') as Map<String, dynamic>;
    return WalletBalance.fromJson(data);
  }

  Future<List<LedgerEntry>> ledger() async {
    if (!AppConfig.useApi) {
      return const [
        LedgerEntry(id: 'l1', title: 'เติมเงินสาธิต', amountBaht: 200, createdAt: '2026-04-01'),
        LedgerEntry(id: 'l2', title: 'สั่งอาหาร', amountBaht: -120, createdAt: '2026-04-02'),
      ];
    }
    final data = await _client.getJson('/v1/wallet/ledger') as Map<String, dynamic>;
    final list = data['entries'] as List<dynamic>? ?? [];
    return list.map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}
