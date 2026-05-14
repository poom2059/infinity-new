import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_strings_th.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_user.dart';
import '../data/merchant/merchant_repository.dart';
import '../domain/food_ordering.dart';
import 'merchant_menu_manage_screen.dart';

const Color _kBodyPrimary = Color(0xFF1A1A1A);
const TextStyle _kFieldTextStyle = TextStyle(color: _kBodyPrimary, fontSize: 16, fontWeight: FontWeight.w500);

/// ลงทะเบียนร้านขายอาหาร — role `merchant_applicant` รอแอดมิน, หลังอนุมัติ `merchant` + `merchant_slug` ตรงกับระบบสั่งอาหาร
class MerchantOnboardingScreen extends StatefulWidget {
  const MerchantOnboardingScreen({
    super.key,
    required this.catalogMerchants,
    required this.onOpenRestaurantDetail,
    required this.onAccountChanged,
  });

  final List<RegisteredMerchant> catalogMerchants;
  final void Function(BuildContext context, RegisteredMerchant merchant) onOpenRestaurantDetail;
  final VoidCallback onAccountChanged;

  @override
  State<MerchantOnboardingScreen> createState() => _MerchantOnboardingScreenState();
}

class _MerchantOnboardingScreenState extends State<MerchantOnboardingScreen> {
  final _shopName = TextEditingController();
  final _category = TextEditingController();
  final _slug = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  AuthUser? _user;
  Map<String, dynamic>? _application;
  String? _error;

  static ThemeData _lightFormTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE3001B), brightness: Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFE3001B),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: Color(0xFF424242), fontSize: 15, fontWeight: FontWeight.w700),
        floatingLabelStyle: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w800),
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE3001B), width: 2),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: Color(0xFFE3001B)),
    );
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _shopName.dispose();
    _category.dispose();
    _slug.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _friendlyLoadError(Object e) {
    final s = e.toString();
    if (s.contains('404') || s.contains('Cannot GET') || s.contains('ไม่พบ API')) {
      return 'เซิร์ฟเวอร์ยังเป็นเวอร์ชันเก่า — ปิดโปรเซสที่พอร์ต 8787 แล้วรัน npm start ในโฟลเดอร์ server อีกครั้ง';
    }
    if (s.length > 220) {
      return '${s.substring(0, 220)}…';
    }
    return s;
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthRepository>();
      final repo = context.read<MerchantRepository>();
      final u = await auth.fetchMe();
      final app = await repo.myLatestApplication();
      if (!mounted) return;
      setState(() {
        _user = u;
        _application = app;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyLoadError(e);
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<MerchantRepository>().submitApplication(
            shopName: _shopName.text.trim(),
            category: _category.text.trim(),
            proposedSlug: _slug.text.trim(),
            notes: _notes.text.trim(),
          );
      if (!mounted) return;
      widget.onAccountChanged();
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyLoadError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openShopBySlug() {
    final slug = _user?.merchantSlug;
    if (slug == null || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีรหัสร้านในระบบ')),
      );
      return;
    }
    RegisteredMerchant? m;
    for (final x in widget.catalogMerchants) {
      if (x.slug == slug) {
        m = x;
        break;
      }
    }
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยังไม่เห็นร้านในรายการ — กลับแท็บหลักเพื่อโหลดร้านใหม่'),
          backgroundColor: Color(0xFFE3001B),
        ),
      );
      return;
    }
    widget.onOpenRestaurantDetail(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _lightFormTheme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('ลงทะเบียนขายอาหาร · ${UiStringsTh.appName}'),
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE3001B)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Material(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 26),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Color(0xFFB71C1C),
                                          fontSize: 15,
                                          height: 1.45,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_user?.role == 'merchant') ...[
                          _infoCard(
                            title: 'ร้านเชื่อมกับระบบสั่งอาหารแล้ว',
                            body:
                                'ลูกค้าสั่งผ่านรหัสร้านเดียวกับที่ตั้งไว้ (ตอนนี้: ${_user!.merchantSlug ?? "—"}) ใช้ปุ่มด้านล่างเพื่อเพิ่มเมนู รูป ราคา และหมวดหมู่ — ออเดอร์จะแสดงในแผงร้านค้าเมื่อมีลูกค้าสั่ง',
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext ctx) => MerchantMenuManageScreen(
                                    onPreviewCustomerView: widget.onOpenRestaurantDetail,
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE3001B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            child: const Text('จัดการเมนูและหมวดหมู่'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _openShopBySlug,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFFE3001B),
                              side: const BorderSide(color: Color(0xFFE3001B), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('ดูหน้าร้านแบบลูกค้า'),
                          ),
                        ] else if (_user?.role == 'merchant_applicant' ||
                            (_application != null && _application!['status'] == 'pending')) ...[
                          _infoCard(
                            title: 'รออนุมัติจากทีมงาน',
                            body:
                                'คำขอของคุณอยู่ระหว่างตรวจสอบ หลังอนุมัติบทบาทจะเป็น «เจ้าของร้าน» และร้านจะปรากฏในรายการสั่งอาหารด้วยรหัสร้านที่กำหนด',
                          ),
                          if (_application != null) ...[
                            const SizedBox(height: 14),
                            _infoCard(
                              title: 'รายละเอียดที่ส่งไว้',
                              body: '',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _detailTile('ชื่อร้าน', '${_application!['shop_name']}'),
                                  _detailTile('หมวด', '${_application!['category']}'),
                                  _detailTile('รหัสร้านในลิงก์', '${_application!['proposed_slug']}'),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          _infoCard(
                            title: 'ขายอาหารบน ${UiStringsTh.appName}',
                            body:
                                'กรอกข้อมูลด้านล่าง รหัสร้านในลิงก์ใช้ตัวอักษรอังกฤษพิมพ์เล็กและขีด เช่น my-noodle-shop — หลังอนุมัติลูกค้าจะสั่งผ่านหน้าเดียวกับร้านอื่นในระบบ',
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _shopName,
                            style: _kFieldTextStyle,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อร้าน',
                              hintText: 'เช่น ก๋วยเตี๋ยวลุงดำ',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _category,
                            style: _kFieldTextStyle,
                            decoration: const InputDecoration(
                              labelText: 'หมวดอาหาร',
                              hintText: 'เช่น ก๋วยเตี๋ยว, ไก่ทอด, ญี่ปุ่น',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _slug,
                            style: _kFieldTextStyle,
                            decoration: const InputDecoration(
                              labelText: 'รหัสร้านในลิงก์ (ภาษาอังกฤษ)',
                              hintText: 'ใช้ตัวอักษร a–z ตัวเลข และขีด เช่น my-noodle-shop',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _notes,
                            style: _kFieldTextStyle,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'หมายเหตุถึงทีมงาน (ไม่บังคับ)',
                              hintText: 'เช่น เวลาเปิดร้าน หรือเลขทะเบียนการค้า',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE3001B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('ส่งคำขอ'),
                          ),
                        ],
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _infoCard({required String title, String body = '', Widget? child}) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _kBodyPrimary, height: 1.2),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(fontSize: 16, height: 1.55, color: Colors.grey.shade900, fontWeight: FontWeight.w500),
              ),
            ],
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.grey.shade800),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: _kBodyPrimary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
