import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../data/admin/admin_repository.dart';

String _roleLabelTh(String role) {
  return switch (role) {
    'customer' => 'ลูกค้า',
    'merchant_applicant' => 'รออนุมัติร้าน',
    'merchant' => 'เจ้าของร้าน',
    'admin' => 'ผู้ดูแลระบบ',
    _ => role,
  };
}

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _bump() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แผงผู้ดูแลระบบ'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFE3001B),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'ใบสมัครร้าน'),
            Tab(text: 'ร้านรออนุมัติ'),
            Tab(text: 'ผู้ใช้ทั้งหมด'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MerchantApplicationsTab(
            key: ValueKey('app$_refreshKey'),
            onAfterMutation: _bump,
          ),
          _PendingMerchantsTab(
            key: ValueKey('mer$_refreshKey'),
            onAfterMutation: _bump,
          ),
          _UsersAdminTab(
            key: ValueKey('usr$_refreshKey'),
            onAfterMutation: _bump,
          ),
        ],
      ),
    );
  }
}

class _MerchantApplicationsTab extends StatelessWidget {
  const _MerchantApplicationsTab({super.key, required this.onAfterMutation});

  final VoidCallback onAfterMutation;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.pendingMerchantApplications(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('ไม่มีใบสมัครรออนุมัติ'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final a = list[i];
            final id = '${a['id']}';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['shop_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text('รหัสร้าน: ${a['proposed_slug']} · ${a['category']}'),
                    Text('ผู้สมัคร: ${a['applicant_name']} (${a['applicant_phone']})'),
                    if ('${a['notes'] ?? ''}'.isNotEmpty) Text('หมายเหตุ: ${a['notes']}'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            try {
                              await repo.approveMerchantApplication(id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('อนุมัติแล้ว')),
                                );
                                onAfterMutation();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                          child: const Text('อนุมัติ'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              await repo.rejectMerchantApplication(id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ปฏิเสธแล้ว')),
                                );
                                onAfterMutation();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          child: const Text('ปฏิเสธ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingMerchantsTab extends StatelessWidget {
  const _PendingMerchantsTab({super.key, required this.onAfterMutation});

  final VoidCallback onAfterMutation;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.pendingMerchants(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('ไม่มีร้านรออนุมัติ'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final m = list[i];
            final mid = '${m['id']}';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text('${m['name']}'),
                subtitle: Text('รหัสร้าน: ${m['slug']}'),
                trailing: FilledButton(
                  onPressed: () async {
                    try {
                      await repo.approveMerchantRecord(mid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('อนุมัติร้านแล้ว')),
                        );
                        onAfterMutation();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  child: const Text('อนุมัติ'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersAdminTab extends StatelessWidget {
  const _UsersAdminTab({super.key, required this.onAfterMutation});

  final VoidCallback onAfterMutation;

  static const List<String> _roles = <String>['customer', 'merchant_applicant', 'merchant', 'admin'];

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.listUsers(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final list = snap.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final u = list[i];
            final id = '${u['id']}';
            final role = '${u['role'] ?? 'customer'}';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('เบอร์ ${u['phone']}'),
                    Text('บทบาท: ${_roleLabelTh(role)}', style: const TextStyle(color: AppColors.textSecondary)),
                    if ('${u['merchant_slug'] ?? ''}'.isNotEmpty)
                      Text(
                        'ร้านที่ผูก: ${u['merchant_slug']}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('เปลี่ยนบทบาท: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _roles.contains(role) ? role : 'customer',
                            items: _roles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(_roleLabelTh(r)),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? next) async {
                              if (next == null || next == role) return;
                              try {
                                await repo.updateUser(id, role: next);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('อัปเดตบทบาทแล้ว')),
                                  );
                                  onAfterMutation();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
