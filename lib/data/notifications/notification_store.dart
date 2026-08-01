import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// หมวดของการแจ้งเตือน — ใช้กำหนดไอคอน/สีในหน้าแสดงผล
enum NotificationCategory { order, promo, wallet, account, system }

extension NotificationCategoryName on NotificationCategory {
  String get id => name;

  static NotificationCategory fromId(String? id) {
    return NotificationCategory.values.firstWhere(
      (NotificationCategory c) => c.name == id,
      orElse: () => NotificationCategory.system,
    );
  }
}

/// รายการแจ้งเตือนหนึ่งรายการ
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  bool read;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'category': category.id,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: '${j['id']}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      category: NotificationCategoryName.fromId(j['category'] as String?),
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      read: j['read'] == true,
    );
  }
}

/// เก็บประวัติการแจ้งเตือนทั้งหมดของแอป (ดูย้อนหลังได้) และบันทึกลง [SharedPreferences]
class NotificationStore extends ChangeNotifier {
  NotificationStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const String _kKey = 'app_notifications_v1';
  static const String _kSeeded = 'app_notifications_seeded_v1';

  final List<AppNotification> _items = <AppNotification>[];

  /// รายการเรียงจากใหม่ไปเก่า
  List<AppNotification> get items {
    final List<AppNotification> sorted = List<AppNotification>.from(_items);
    sorted.sort((AppNotification a, AppNotification b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  int get unreadCount => _items.where((AppNotification n) => !n.read).length;
  bool get isEmpty => _items.isEmpty;

  void _load() {
    final String? raw = _prefs.getString(_kKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(list.map((dynamic e) => AppNotification.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        _items.clear();
      }
    }
    if (_prefs.getBool(_kSeeded) != true) {
      _seedDemo();
      _prefs.setBool(_kSeeded, true);
      _persist();
    }
  }

  void _seedDemo() {
    final DateTime now = DateTime.now();
    _items.addAll(<AppNotification>[
      AppNotification(
        id: 'seed-order-1',
        title: 'ออเดอร์ #INF1042 จัดส่งสำเร็จ',
        body: 'ไรเดอร์ส่งอาหารถึงปลายทางแล้ว ขอบคุณที่ใช้บริการ อย่าลืมให้คะแนนร้านนะ',
        category: NotificationCategory.order,
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      AppNotification(
        id: 'seed-promo-1',
        title: 'ส่งฟรี 3 กม. วันนี้เท่านั้น',
        body: 'สั่งจากร้านร่วมรายการในรัศมี 3 กม. รับสิทธิ์ส่งฟรีทันที ไม่มีขั้นต่ำ',
        category: NotificationCategory.promo,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'seed-wallet-1',
        title: 'เติมเงินเข้ากระเป๋าสำเร็จ ฿500',
        body: 'ยอดเงินคงเหลือในกระเป๋าของคุณพร้อมใช้งานแล้ว',
        category: NotificationCategory.wallet,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: 'seed-account-1',
        title: 'ยินดีต้อนรับสู่ Infinity',
        body: 'ตั้งค่าโปรไฟล์และยืนยันตัวตนเพื่อปลดล็อกวงเงินและบริการเพิ่มเติม',
        category: NotificationCategory.account,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      AppNotification(
        id: 'seed-promo-2',
        title: 'ลดสูงสุด 60% ดีลแฟลช',
        body: 'เฉพาะช่วงเวลาจำกัด เลือกเมนูที่ติดป้ายโปรในร้านที่ร่วมรายการ',
        category: NotificationCategory.promo,
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
      ),
      AppNotification(
        id: 'seed-system-1',
        title: 'อัปเดตเงื่อนไขการให้บริการ',
        body: 'เราปรับปรุงนโยบายความเป็นส่วนตัวเพื่อความปลอดภัยของข้อมูลคุณ',
        category: NotificationCategory.system,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ]);
  }

  /// เพิ่มการแจ้งเตือนใหม่ (เช่น เมื่อมีเหตุการณ์ในแอป)
  Future<void> add({
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
  }) async {
    _items.add(AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    var changed = false;
    for (final AppNotification n in _items) {
      if (n.id == id && !n.read) {
        n.read = true;
        changed = true;
        break;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    var changed = false;
    for (final AppNotification n in _items) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((AppNotification e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final String raw = jsonEncode(_items.map((AppNotification e) => e.toJson()).toList());
    await _prefs.setString(_kKey, raw);
  }
}
