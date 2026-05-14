import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/api/api_exception.dart';
import '../data/merchant/merchant_repository.dart';
import '../domain/food_ordering.dart';

const Color _kRed = Color(0xFFE3001B);
const Color _kBody = Color(0xFF0D0D0D);
const Color _kMuted = Color(0xFF424242);
const Color _kSurface = Color(0xFFF5F6F8);

/// หมวดแนะนำ — ร้านเลือกได้หรือพิมพ์หมวดเองในฟอร์ม
const List<String> kPresetMenuSections = [
  'อาหารและเครื่องดื่ม',
  'ของหวาน',
  'ผลไม้',
  'อื่นๆ',
];

ThemeData _merchantMenuTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: _kRed, brightness: Brightness.light),
    scaffoldBackgroundColor: _kSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: _kRed,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _kMuted, fontSize: 15, fontWeight: FontWeight.w700),
      floatingLabelStyle: const TextStyle(color: _kRed, fontWeight: FontWeight.w800),
      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kRed, width: 2),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: _kRed),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade200,
      selectedColor: _kRed,
      disabledColor: Colors.grey.shade300,
      labelStyle: const TextStyle(color: _kBody, fontSize: 14, fontWeight: FontWeight.w700),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade500)),
    ),
  );
  return base;
}

String _friendlyError(Object e) {
  if (e is ApiException) {
    if (e.statusCode == 401) {
      return 'หมดเซสชัน — ออกจากระบบแล้วล็อกอินใหม่';
    }
    if (e.statusCode == 403) {
      return 'บัญชีนี้ยังไม่ใช่เจ้าของร้าน หรือยังไม่ได้รับอนุมัติ';
    }
    if (e.statusCode == 404) {
      return 'ยังไม่มีร้านผูกกับบัญชี หรือเซิร์ฟเวอร์ยังไม่อัปเดต — ลองรีสตาร์ท API แล้วลองใหม่';
    }
    return e.message;
  }
  final s = e.toString();
  if (s.length > 200) {
    return '${s.substring(0, 200)}…';
  }
  return s;
}

String _mimeFromImageBytes(List<int> bytes) {
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

/// จัดการเมนูร้านตัวเอง: รูป ราคา รายละเอียด หมวดหมู่ ไม่จำกัดจำนวนรายการ
class MerchantMenuManageScreen extends StatefulWidget {
  const MerchantMenuManageScreen({super.key, this.onPreviewCustomerView});

  /// เปิดหน้าร้านมุมลูกค้า (ส่ง [RegisteredMerchant] จากแคตตาล็อก)
  final void Function(BuildContext context, RegisteredMerchant merchant)? onPreviewCustomerView;

  @override
  State<MerchantMenuManageScreen> createState() => _MerchantMenuManageScreenState();
}

class _MerchantMenuManageScreenState extends State<MerchantMenuManageScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _merchant;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<MerchantRepository>().fetchMyMenu();
      if (!mounted) return;
      final list = (data['items'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      list.sort((a, b) {
        final c = '${a['menu_section'] ?? ''}'.compareTo('${b['menu_section'] ?? ''}');
        if (c != 0) return c;
        return '${a['name']}'.compareTo('${b['name']}');
      });
      setState(() {
        _merchant = data['merchant'] as Map<String, dynamic>?;
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final repo = context.read<MerchantRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final nameC = TextEditingController(text: existing == null ? '' : '${existing['name']}');
    final priceC = TextEditingController(text: existing == null ? '' : '${existing['price']}');
    final descC = TextEditingController(text: existing == null ? '' : '${existing['description'] ?? ''}');
    final imageLinkC = TextEditingController(text: existing == null ? '' : _linkOnlyIfNetwork('${existing['image_url'] ?? ''}'));
    final customSectionC = TextEditingController();
    final List<bool> imageClearedFlag = <bool>[false];
    String section = existing == null
        ? kPresetMenuSections.first
        : '${existing['menu_section'] ?? 'อื่นๆ'}'.trim().isEmpty
            ? 'อื่นๆ'
            : '${existing['menu_section']}';
    if (!kPresetMenuSections.contains(section)) {
      customSectionC.text = section;
      section = '__custom__';
    }
    String? pickedDataUrl;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Theme(
          data: _merchantMenuTheme(),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                Future<void> pickImage() async {
                  try {
                    final picker = ImagePicker();
                    final x = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1200,
                      imageQuality: 80,
                    );
                    if (x == null) return;
                    final bytes = await x.readAsBytes();
                    if (bytes.length > 850000) {
                      if (ctx.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('ไฟล์ใหญ่เกินไป — ลองรูปที่เล็กลง หรือใส่ลิงก์รูปแทน'),
                            backgroundColor: Color(0xFFB71C1C),
                          ),
                        );
                      }
                      return;
                    }
                    final mime = _mimeFromImageBytes(bytes);
                    final b64 = base64Encode(bytes);
                    setModal(() {
                      pickedDataUrl = 'data:$mime;base64,$b64';
                      imageLinkC.clear();
                      imageClearedFlag[0] = false;
                    });
                  } catch (e) {
                    if (ctx.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('เลือกรูปไม่สำเร็จ — ลองใส่ลิงก์รูปด้านล่าง\n${_friendlyError(e)}'),
                          backgroundColor: const Color(0xFFB71C1C),
                        ),
                      );
                    }
                  }
                }

                String resolvedSection() {
                  if (section == '__custom__') {
                    final t = customSectionC.text.trim();
                    return t.isEmpty ? 'อื่นๆ' : t;
                  }
                  return section;
                }

                String? resolvedImageUrl() {
                  if (imageClearedFlag[0]) {
                    return null;
                  }
                  if (pickedDataUrl != null && pickedDataUrl!.isNotEmpty) {
                    return pickedDataUrl;
                  }
                  final link = imageLinkC.text.trim();
                  if (link.isNotEmpty) {
                    return link;
                  }
                  if (existing != null) {
                    final o = '${existing['image_url'] ?? ''}'.trim();
                    if (o.isNotEmpty) {
                      return o;
                    }
                  }
                  return null;
                }

                String previewImageUrl() {
                  if (imageClearedFlag[0]) {
                    return '';
                  }
                  if (pickedDataUrl != null && pickedDataUrl!.isNotEmpty) {
                    return pickedDataUrl!;
                  }
                  final link = imageLinkC.text.trim();
                  if (link.isNotEmpty) {
                    return link;
                  }
                  return '${existing?['image_url'] ?? ''}'.trim();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        existing == null ? 'เพิ่มเมนู' : 'แก้ไขเมนู',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kBody, height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kIsWeb
                            ? 'กรอกข้อความให้ครบ — รูปเลือกจากเครื่องหรือวางลิงก์ที่ลงท้ายด้วย .jpg / .png'
                            : 'กรอกชื่อและราคา — รูปเลือกจากแกลเลอรีหรือวางลิงก์รูป',
                        style: const TextStyle(fontSize: 15, color: _kMuted, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameC,
                        style: const TextStyle(fontSize: 16, color: _kBody, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(labelText: 'ชื่อเมนู *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceC,
                        style: const TextStyle(fontSize: 16, color: _kBody, fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'ราคา (บาท) *', hintText: 'เช่น 89'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descC,
                        style: const TextStyle(fontSize: 16, color: _kBody, fontWeight: FontWeight.w500),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด (ไม่บังคับ)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'หมวดหมู่',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _kBody),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          ...kPresetMenuSections.map(
                            (s) {
                              final sel = section == s;
                              return FilterChip(
                                label: Text(s),
                                selected: sel,
                                onSelected: (_) => setModal(() => section = s),
                                showCheckmark: true,
                                checkmarkColor: Colors.white,
                                selectedColor: _kRed,
                                labelStyle: TextStyle(
                                  color: sel ? Colors.white : _kBody,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                side: BorderSide(color: sel ? _kRed : Colors.grey.shade600, width: sel ? 0 : 1.2),
                                backgroundColor: sel ? _kRed : Colors.grey.shade100,
                              );
                            },
                          ),
                          FilterChip(
                            label: const Text('กำหนดเอง'),
                            selected: section == '__custom__',
                            onSelected: (_) => setModal(() => section = '__custom__'),
                            showCheckmark: true,
                            checkmarkColor: Colors.white,
                            selectedColor: _kRed,
                            labelStyle: TextStyle(
                              color: section == '__custom__' ? Colors.white : _kBody,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            side: BorderSide(
                              color: section == '__custom__' ? _kRed : Colors.grey.shade600,
                              width: section == '__custom__' ? 0 : 1.2,
                            ),
                            backgroundColor: section == '__custom__' ? _kRed : Colors.grey.shade100,
                          ),
                        ],
                      ),
                      if (section == '__custom__') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customSectionC,
                          style: const TextStyle(fontSize: 16, color: _kBody, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            labelText: 'ชื่อหมวดของคุณ',
                            hintText: 'เช่น อาหารเจ ของทานเล่น',
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'รูปเมนู',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _kBody),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('เลือกรูป'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (pickedDataUrl != null && pickedDataUrl!.isNotEmpty)
                            TextButton(
                              onPressed: () => setModal(() {
                                pickedDataUrl = null;
                              }),
                              child: const Text('เอารูปจากไฟล์ออก', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          if (existing != null && '${existing['image_url'] ?? ''}'.trim().isNotEmpty)
                            TextButton(
                              onPressed: () => setModal(() {
                                pickedDataUrl = null;
                                imageLinkC.clear();
                                imageClearedFlag[0] = true;
                              }),
                              child: const Text('ลบรูปทั้งหมด', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: imageLinkC,
                        style: const TextStyle(fontSize: 15, color: _kBody, fontWeight: FontWeight.w500),
                        onChanged: (_) {
                          setModal(() {
                            if (imageLinkC.text.trim().isNotEmpty) {
                              pickedDataUrl = null;
                              imageClearedFlag[0] = false;
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'หรือวางลิงก์รูป (https://…)',
                          hintText: 'https://…',
                        ),
                      ),
                      if (previewImageUrl().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _thumbFromUrl(previewImageUrl(), height: 160),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () async {
                          final name = nameC.text.trim();
                          final price = int.tryParse(priceC.text.trim());
                          if (name.isEmpty || price == null || price < 0) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('กรอกชื่อเมนูและราคาเป็นตัวเลขให้ครบ'),
                                backgroundColor: Color(0xFFB71C1C),
                              ),
                            );
                            return;
                          }
                          final img = resolvedImageUrl();
                          try {
                            if (existing == null) {
                              await repo.createMenuItem(
                                name: name,
                                price: price,
                                description: descC.text.trim(),
                                imageUrl: img,
                                menuSection: resolvedSection(),
                              );
                            } else {
                              final hadImage = '${existing['image_url'] ?? ''}'.trim().isNotEmpty;
                              final nowEmpty = img == null || img.isEmpty;
                              final cleared = hadImage && nowEmpty;
                              await repo.updateMenuItem(
                                '${existing['id']}',
                                name: name,
                                price: price,
                                description: descC.text.trim(),
                                menuSection: resolvedSection(),
                                imageUrl: cleared ? null : img,
                                clearImage: cleared,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(_friendlyError(e)),
                                backgroundColor: const Color(0xFFB71C1C),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          existing == null ? 'เพิ่มเมนู' : 'บันทึก',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    nameC.dispose();
    priceC.dispose();
    descC.dispose();
    imageLinkC.dispose();
    customSectionC.dispose();
    if (ok == true && mounted) await _load();
  }

  String _linkOnlyIfNetwork(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '';
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: _merchantMenuTheme(),
        child: AlertDialog(
          title: const Text('ลบเมนู', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            'ต้องการลบ «${row['name']}» ใช่หรือไม่?',
            style: const TextStyle(fontSize: 16, height: 1.45, color: _kBody, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white),
              child: const Text('ลบ'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<MerchantRepository>().deleteMenuItem('${row['id']}');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e)), backgroundColor: const Color(0xFFB71C1C)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopName = '${_merchant?['name'] ?? 'ร้านของฉัน'}';
    return Theme(
      data: _merchantMenuTheme(),
      child: Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(
          title: const Text('จัดการเมนูและหมวดหมู่'),
          actions: [
            if (widget.onPreviewCustomerView != null && _merchant != null)
              IconButton(
                tooltip: 'ดูแบบลูกค้า',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () {
                  final slug = '${_merchant!['slug'] ?? ''}';
                  if (slug.isEmpty) return;
                  final m = RegisteredMerchant(
                    slug: slug,
                    name: shopName,
                    category: '${_merchant!['category'] ?? ''}',
                    etaMinutes: (_merchant!['eta_minutes'] as num?)?.toInt() ?? 20,
                    rating: (_merchant!['rating'] as num?)?.toDouble() ?? 4.5,
                    usageCount: (_merchant!['usage_count'] as num?)?.toInt() ?? 0,
                    imageUrl: '${_merchant!['image_url'] ?? ''}',
                    distanceKm: (_merchant!['distance_km'] as num?)?.toDouble() ?? 2,
                    deliveryFee: (_merchant!['delivery_fee'] as num?)?.toInt() ?? 0,
                  );
                  widget.onPreviewCustomerView!(context, m);
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kRed))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFB71C1C)),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
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
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('ลองโหลดอีกครั้ง'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: _kRed,
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              elevation: 1,
                              shadowColor: Colors.black12,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shopName,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kBody, height: 1.2),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'เมนู ${_items.length} รายการ · แตะแถวเพื่อแก้ไข · ปุ่ม + มุมล่างขวาเพื่อเพิ่ม',
                                      style: const TextStyle(fontSize: 15, color: _kMuted, fontWeight: FontWeight.w700, height: 1.45),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'ยังไม่มีเมนู\nกดปุ่ม «เพิ่มเมนู» มุมล่างขวา',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.5,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final row = _items[i];
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    elevation: 1,
                                    shadowColor: Colors.black12,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: () => _openEditor(existing: row),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: SizedBox(
                                                      width: 76,
                                                      height: 76,
                                                      child: _thumbFromUrl('${row['image_url'] ?? ''}', height: 76),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          '${row['name']}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 17,
                                                            color: _kBody,
                                                            height: 1.25,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFFEBEE),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            '${row['menu_section'] ?? 'อื่นๆ'}',
                                                            style: const TextStyle(
                                                              fontSize: 13,
                                                              color: Color(0xFFB71C1C),
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                          ),
                                                        ),
                                                        if ('${row['description'] ?? ''}'.trim().isNotEmpty) ...[
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            '${row['description']}',
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              height: 1.4,
                                                              color: _kMuted,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          '฿${row['price']}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 20,
                                                            color: _kRed,
                                                            height: 1.1,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'ลบ',
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB71C1C), size: 26),
                                          onPressed: () => _confirmDelete(row),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: _items.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                      ],
                    ),
                  ),
        floatingActionButton: _loading || _error != null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openEditor(),
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('เพิ่มเมนู', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
      ),
    );
  }
}

Widget _thumbFromUrl(String url, {required double height}) {
  if (url.isEmpty) {
    return ColoredBox(
      color: const Color(0xFFE8EAEE),
      child: Icon(Icons.restaurant_menu_rounded, size: height * 0.42, color: Color(0xFF757575)),
    );
  }
  if (url.startsWith('data:image')) {
    try {
      final i = url.indexOf(',');
      if (i <= 0) throw StateError('bad data url');
      final b64 = url.substring(i + 1);
      final bytes = base64Decode(b64);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        height: height,
        width: height,
        gaplessPlayback: true,
      );
    } catch (_) {
      return ColoredBox(
        color: const Color(0xFFE8EAEE),
        child: Icon(Icons.broken_image_outlined, size: height * 0.42, color: Color(0xFF757575)),
      );
    }
  }
  return Image.network(
    url,
    fit: BoxFit.cover,
    height: height,
    width: height,
    errorBuilder: (context, error, stackTrace) => ColoredBox(
      color: const Color(0xFFE8EAEE),
      child: Icon(Icons.restaurant_menu_rounded, size: height * 0.42, color: Color(0xFF757575)),
    ),
  );
}
