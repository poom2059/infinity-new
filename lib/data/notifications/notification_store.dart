import 'package:flutter/foundation.dart';

import '../api/infinity_api_client.dart';

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

  factory AppNotification.fromApi(Map<String, dynamic> j) {
    return AppNotification(
      id: '${j['id']}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      category: NotificationCategoryName.fromId('${j['category'] ?? 'system'}'),
      createdAt: DateTime.tryParse('${j['created_at'] ?? j['createdAt']}') ?? DateTime.now(),
      read: j['read'] == true || j['read'] == 1 || j['read_at'] != null,
    );
  }
}

/// ดึงการแจ้งเตือนจาก API
class NotificationStore extends ChangeNotifier {
  NotificationStore(this._client);

  final InfinityApiClient _client;
  final List<AppNotification> _items = <AppNotification>[];

  List<AppNotification> get items {
    final List<AppNotification> sorted = List<AppNotification>.from(_items);
    sorted.sort((AppNotification a, AppNotification b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  int get unreadCount => _items.where((AppNotification n) => !n.read).length;
  bool get isEmpty => _items.isEmpty;

  Future<void> refresh() async {
    final data = await _client.getJson('/v1/notifications') as Map<String, dynamic>;
    final list = data['notifications'] as List<dynamic>? ?? [];
    _items
      ..clear()
      ..addAll(list.map((e) => AppNotification.fromApi(e as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    await _client.postJson('/v1/notifications/$id/read', {});
    for (final AppNotification n in _items) {
      if (n.id == id) n.read = true;
    }
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final AppNotification n in _items.where((n) => !n.read)) {
      await markRead(n.id);
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((AppNotification e) => e.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();
  }
}
