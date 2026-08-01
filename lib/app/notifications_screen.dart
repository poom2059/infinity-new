import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import '../data/notifications/notification_store.dart';

/// หน้าศูนย์การแจ้งเตือน — แสดงประวัติการแจ้งเตือนทั้งหมด ดูย้อนหลังได้
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotificationStore>();
    final List<AppNotification> items = store.items;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.topBar,
        foregroundColor: AppColors.topBarFg,
        title: const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (store.unreadCount > 0)
            TextButton(
              onPressed: () => store.markAllRead(),
              child: const Text(
                'อ่านทั้งหมด',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
              ),
            ),
          if (!store.isEmpty)
            PopupMenuButton<String>(
              color: AppColors.surfaceElevated,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (String v) {
                if (v == 'clear') {
                  _confirmClear(context, store);
                }
              },
              itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'clear',
                  child: Text('ล้างการแจ้งเตือนทั้งหมด', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ],
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int i) {
                final AppNotification n = items[i];
                final bool showHeader = i == 0 || _dayBucket(items[i - 1].createdAt) != _dayBucket(n.createdAt);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader) _SectionHeader(label: _dayBucket(n.createdAt)),
                    _NotificationTile(
                      item: n,
                      onTap: () => store.markRead(n.id),
                      onDismiss: () => store.remove(n.id),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, NotificationStore store) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text('ล้างการแจ้งเตือน', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'ต้องการลบการแจ้งเตือนทั้งหมดหรือไม่? ประวัติจะถูกล้างและกู้คืนไม่ได้',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                store.clearAll();
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('ล้างทั้งหมด'),
            ),
          ],
        );
      },
    );
  }
}

String _dayBucket(DateTime dt) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(dt.year, dt.month, dt.day);
  final int diff = today.difference(day).inDays;
  if (diff <= 0) {
    return 'วันนี้';
  }
  if (diff == 1) {
    return 'เมื่อวาน';
  }
  if (diff < 7) {
    return '$diff วันก่อน';
  }
  return '${day.day}/${day.month}/${day.year + 543}';
}

String _timeAgo(DateTime dt) {
  final Duration d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) {
    return 'เมื่อสักครู่';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes} นาทีที่แล้ว';
  }
  if (d.inHours < 24) {
    return '${d.inHours} ชม.ที่แล้ว';
  }
  if (d.inDays < 7) {
    return '${d.inDays} วันที่แล้ว';
  }
  final String hh = dt.hour.toString().padLeft(2, '0');
  final String mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day}/${dt.month} $hh:$mm';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap, required this.onDismiss});

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final _CategoryStyle style = _styleFor(item.category);
    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        color: const Color(0xFF5A1A1A),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: item.read ? AppColors.canvas : AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!item.read)
                            Container(
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(item.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 14),
          const Text(
            'ยังไม่มีการแจ้งเตือน',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'การแจ้งเตือนเกี่ยวกับออเดอร์ โปรโมชัน และบัญชีจะแสดงที่นี่',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CategoryStyle {
  const _CategoryStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_CategoryStyle _styleFor(NotificationCategory c) {
  switch (c) {
    case NotificationCategory.order:
      return const _CategoryStyle(Icons.local_shipping_outlined, Color(0xFF2ECC71));
    case NotificationCategory.promo:
      return const _CategoryStyle(Icons.local_offer_outlined, Color(0xFFFF8A00));
    case NotificationCategory.wallet:
      return const _CategoryStyle(Icons.account_balance_wallet_outlined, Color(0xFF4DA3FF));
    case NotificationCategory.account:
      return const _CategoryStyle(Icons.person_outline_rounded, Color(0xFFB07CFF));
    case NotificationCategory.system:
      return const _CategoryStyle(Icons.campaign_outlined, Color(0xFFE3001B));
  }
}
