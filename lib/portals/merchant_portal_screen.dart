import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api/api_exception.dart';
import '../data/merchant/merchant_repository.dart';

const Color _kRed = Color(0xFFE3001B);
const Color _kBody = Color(0xFF0D0D0D);
const Color _kMuted = Color(0xFF424242);

ThemeData _merchantPortalTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: _kRed, brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF5F6F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: _kRed,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

String _friendlyError(Object e) {
  if (e is ApiException) {
    if (e.statusCode == 401) {
      return 'หมดเซสชัน — ล็อกอินใหม่';
    }
    if (e.statusCode == 403) {
      return 'บัญชีนี้ยังไม่ใช่เจ้าของร้าน';
    }
    return e.message;
  }
  final s = e.toString();
  return s.length > 180 ? '${s.substring(0, 180)}…' : s;
}

String _linesSummary(dynamic linesField) {
  if (linesField == null) {
    return '—';
  }
  List<dynamic> list;
  if (linesField is String) {
    if (linesField.isEmpty) {
      return '—';
    }
    try {
      list = jsonDecode(linesField) as List<dynamic>? ?? [];
    } catch (_) {
      return '—';
    }
  } else if (linesField is List<dynamic>) {
    list = linesField;
  } else {
    return '—';
  }
  if (list.isEmpty) {
    return '—';
  }
  final parts = <String>[];
  for (final e in list.take(5)) {
    if (e is! Map) {
      continue;
    }
    final m = Map<String, dynamic>.from(e);
    final name = '${m['item_name'] ?? m['name'] ?? 'เมนู'}';
    final q = (m['qty'] as num?)?.toInt() ?? 1;
    parts.add('$name ×$q');
  }
  final more = list.length > 5 ? ' …' : '';
  return parts.join(' · ') + more;
}

String _formatPlacedAt(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) {
    return iso?.isNotEmpty == true ? iso! : '—';
  }
  final local = d.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $h:$min น.';
}

Color _statusBg(String status) {
  final s = status.trim();
  if (s.contains('สำเร็จ') || s.toLowerCase().contains('complete')) {
    return const Color(0xFFE8F5E9);
  }
  if (s.contains('ยกเลิก') || s.contains('cancel')) {
    return const Color(0xFFFFEBEE);
  }
  return const Color(0xFFFFF8E1);
}

Color _statusFg(String status) {
  final s = status.trim();
  if (s.contains('สำเร็จ') || s.toLowerCase().contains('complete')) {
    return const Color(0xFF1B5E20);
  }
  if (s.contains('ยกเลิก') || s.contains('cancel')) {
    return const Color(0xFFB71C1C);
  }
  return const Color(0xFFE65100);
}

/// แผงร้านค้า — ออเดอร์จากลูกค้า (โหมด API)
class MerchantPortalScreen extends StatefulWidget {
  const MerchantPortalScreen({super.key});

  @override
  State<MerchantPortalScreen> createState() => _MerchantPortalScreenState();
}

class _MerchantPortalScreenState extends State<MerchantPortalScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() {
    return context.read<MerchantRepository>().recentOrders();
  }

  void _reload() {
    setState(() {
      _ordersFuture = _fetchOrders();
    });
  }

  Future<void> _refresh() async {
    final f = _fetchOrders();
    setState(() => _ordersFuture = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _merchantPortalTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('แผงร้านค้า'),
          actions: [
            IconButton(
              tooltip: 'รีเฟรช',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ordersFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _kRed),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFB71C1C)),
                      const SizedBox(height: 16),
                      Text(
                        _friendlyError(snap.error!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: _kBody,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('ลองอีกครั้ง'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return RefreshIndicator(
                color: _kRed,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 48),
                    Center(
                      child: Text(
                        'ยังไม่มีออเดอร์\nเมื่อลูกค้าสั่งเข้าร้านคุณ รายการจะแสดงที่นี่',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.55,
                          color: _kMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: _kRed,
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final o = list[i];
                  final id = '${o['id'] ?? ''}';
                  final total = o['total_baht'];
                  final totalStr = total is num ? '฿${total.toInt()}' : '฿$total';
                  final status = '${o['status'] ?? '—'}';
                  final placed = _formatPlacedAt('${o['placed_at'] ?? ''}');
                  final pickup = o['pickup_mode'] == true || o['pickup_mode'] == 1;
                  final linesRaw = o['lines'] ?? o['lines_json'];
                  final summary = _linesSummary(linesRaw);

                  return Material(
                    color: Colors.white,
                    elevation: 1,
                    shadowColor: Colors.black12,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      id,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: _kBody,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      placed,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: _kMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _statusBg(status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _statusFg(status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: _kBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                pickup ? Icons.storefront_outlined : Icons.delivery_dining_rounded,
                                size: 20,
                                color: _kMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pickup ? 'รับที่ร้าน' : 'จัดส่ง',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kMuted,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                totalStr,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _kRed,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
