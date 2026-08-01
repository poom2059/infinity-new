import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_theme.dart';
import 'google_geo_service.dart';
import '../data/places/saved_places_store.dart';

/// หน้าปักหมุดที่อยู่บนแผนที่ (Google Maps) — เลื่อนแผนที่ให้หมุดอยู่ตรงตำแหน่ง
///
/// คืนค่า [SavedPlace] เมื่อผู้ใช้กดบันทึก
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial});

  /// ที่อยู่เดิม (กรณีแก้ไข) — ถ้า null จะเริ่มที่กลางกรุงเทพฯ
  final SavedPlace? initial;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _bangkok = LatLng(13.7563, 100.5018);

  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _customLabel = TextEditingController();
  final GoogleGeoService _geo = GoogleGeoService();

  late LatLng _center;
  String _label = 'บ้าน';
  String _addressText = '';
  bool _loadingAddress = false;
  bool _searching = false;

  Timer? _debounce;
  List<GeoSuggestion> _suggestions = <GeoSuggestion>[];
  bool _suggesting = false;

  static const List<String> _presetLabels = <String>['บ้าน', 'ที่ทำงาน', 'อื่นๆ'];

  @override
  void initState() {
    super.initState();
    final SavedPlace? init = widget.initial;
    _center = init != null ? LatLng(init.lat, init.lng) : _bangkok;
    if (init != null) {
      _detail.text = init.detail;
      if (_presetLabels.contains(init.label)) {
        _label = init.label;
      } else {
        _label = 'อื่นๆ';
        _customLabel.text = init.label;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _reverseGeocode(_center));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _detail.dispose();
    _customLabel.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _loadingAddress = true);
    final String? name = await _geo.reverseGeocode(p.latitude, p.longitude);
    if (!mounted) {
      return;
    }
    if (name != null && name.isNotEmpty) {
      setState(() {
        _addressText = name;
        _loadingAddress = false;
      });
      if (_detail.text.trim().isEmpty) {
        _detail.text = name;
      }
      return;
    }
    setState(() {
      _addressText = 'พิกัด ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
      _loadingAddress = false;
    });
  }

  /// เรียกขณะพิมพ์ — หน่วงเวลา 350ms แล้วค่อยดึงรายการแนะนำ (กัน rate-limit)
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final String q = value.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = <GeoSuggestion>[];
        _suggesting = false;
      });
      return;
    }
    setState(() => _suggesting = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    final List<GeoSuggestion> items = await _geo.autocomplete(q);
    if (mounted) {
      setState(() {
        _suggestions = items;
        _suggesting = false;
      });
    }
  }

  /// เลือกผลลัพธ์จากรายการแนะนำ → เลื่อนแผนที่ไปยังตำแหน่งนั้น
  Future<void> _selectSuggestion(GeoSuggestion s) async {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    _search.text = s.mainText;
    setState(() {
      _suggestions = <GeoSuggestion>[];
      _suggesting = false;
      _loadingAddress = true;
    });
    final GeoResult? r = await _geo.geocodePlaceId(s.placeId);
    if (!mounted) {
      return;
    }
    if (r == null) {
      setState(() => _loadingAddress = false);
      _toast('ดึงตำแหน่งของสถานที่ไม่สำเร็จ');
      return;
    }
    final LatLng target = LatLng(r.lat, r.lng);
    _center = target;
    final GoogleMapController c = await _controller.future;
    await c.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    if (mounted) {
      setState(() {
        _addressText = r.address;
        _loadingAddress = false;
      });
      _detail.text = r.address;
    }
  }

  /// กด Enter / ปุ่มค้นหา — ใช้ผลแรกถ้ามี ไม่งั้นค้นหาตรงๆ
  Future<void> _runSearch() async {
    if (_suggestions.isNotEmpty) {
      await _selectSuggestion(_suggestions.first);
      return;
    }
    final String q = _search.text.trim();
    if (q.isEmpty) {
      return;
    }
    setState(() => _searching = true);
    final List<GeoSuggestion> items = await _geo.autocomplete(q);
    if (!mounted) {
      return;
    }
    setState(() => _searching = false);
    if (items.isNotEmpty) {
      setState(() => _suggestions = items);
      await _selectSuggestion(items.first);
    } else {
      _toast('ไม่พบสถานที่ที่ค้นหา');
    }
  }

  Future<void> _zoom(bool zoomIn) async {
    final GoogleMapController c = await _controller.future;
    await c.animateCamera(zoomIn ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut());
  }

  void _save() {
    final String label = _label == 'อื่นๆ' ? _customLabel.text.trim() : _label;
    if (label.isEmpty) {
      _toast('ตั้งชื่อที่อยู่ก่อน');
      return;
    }
    final String detail = _detail.text.trim().isEmpty ? _addressText : _detail.text.trim();
    final SavedPlace place = SavedPlace(
      id: widget.initial?.id ?? 'place-${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      detail: detail,
      lat: _center.latitude,
      lng: _center.longitude,
    );
    Navigator.of(context).pop(place);
  }

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  /// แผนที่ถูกสร้างครั้งเดียวแล้ว cache ไว้ — กัน GoogleMap re-render ทุกครั้งที่
  /// setState (พิมพ์ค้นหา/โหลด) ซึ่งทำให้จอสั่น
  Widget? _mapCache;
  Widget _buildMap() {
    return _mapCache ??= GoogleMap(
      initialCameraPosition: CameraPosition(target: _center, zoom: 15),
      onMapCreated: (GoogleMapController c) {
        if (!_controller.isCompleted) {
          _controller.complete(c);
        }
      },
      onCameraMoveStarted: () {
        if (!_loadingAddress) {
          setState(() => _loadingAddress = true);
        }
      },
      onCameraMove: (CameraPosition pos) => _center = pos.target,
      onCameraIdle: () => _reverseGeocode(_center),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.topBar,
        foregroundColor: AppColors.topBarFg,
        title: Text(widget.initial == null ? 'ปักหมุดที่อยู่' : 'แก้ไขที่อยู่',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildMap(),
                // หมุดกลางจอ (ยกขึ้นครึ่งหนึ่งให้ปลายหมุดชี้ตรงกลางพอดี)
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.location_on, size: 48, color: Color(0xFFE3001B)),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.surface,
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _runSearch(),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาสถานที่ เช่น เซ็นทรัลลาดพร้าว',
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                            suffixIcon: (_searching || _suggesting || _loadingAddress)
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : (_search.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                                        onPressed: () {
                                          _search.clear();
                                          _debounce?.cancel();
                                          setState(() {
                                            _suggestions = <GeoSuggestion>[];
                                            _suggesting = false;
                                          });
                                        },
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.accent),
                                        onPressed: _runSearch,
                                      )),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (BuildContext context, int i) {
                                final GeoSuggestion s = _suggestions[i];
                                return InkWell(
                                  onTap: () => _selectSuggestion(s),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    child: Row(
                                      children: <Widget>[
                                        const Icon(Icons.place_outlined, size: 20, color: AppColors.accent),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                s.mainText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (s.secondaryText.isNotEmpty) ...<Widget>[
                                                const SizedBox(height: 2),
                                                Text(
                                                  s.secondaryText,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      _MapZoomButton(icon: Icons.add, onTap: () => _zoom(true)),
                      const SizedBox(height: 8),
                      _MapZoomButton(icon: Icons.remove, onTap: () => _zoom(false)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _PickerPanel(
            addressText: _addressText,
            loadingAddress: _loadingAddress,
            label: _label,
            presetLabels: _presetLabels,
            customLabel: _customLabel,
            detail: _detail,
            onLabel: (String v) => setState(() => _label = v),
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _PickerPanel extends StatelessWidget {
  const _PickerPanel({
    required this.addressText,
    required this.loadingAddress,
    required this.label,
    required this.presetLabels,
    required this.customLabel,
    required this.detail,
    required this.onLabel,
    required this.onSave,
  });

  final String addressText;
  final bool loadingAddress;
  final String label;
  final List<String> presetLabels;
  final TextEditingController customLabel;
  final TextEditingController detail;
  final ValueChanged<String> onLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ความสูงคงที่ (เผื่อ 2 บรรทัด) เพื่อไม่ให้แผงล่างขยับ → กันจอสั่น
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.place_outlined, size: 18, color: AppColors.accent),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    addressText.isNotEmpty
                        ? addressText
                        : (loadingAddress ? 'กำลังอ่านที่อยู่…' : 'เลื่อนแผนที่เพื่อเลือกตำแหน่ง'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: addressText.isEmpty ? AppColors.textMuted : AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final String l in presetLabels) ...[
                ChoiceChip(
                  label: Text(l),
                  selected: label == l,
                  onSelected: (_) => onLabel(l),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: label == l ? Colors.white : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: label == l ? AppColors.accent : AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          if (label == 'อื่นๆ') ...[
            const SizedBox(height: 12),
            TextField(
              controller: customLabel,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _dec('ชื่อที่อยู่ เช่น บ้านพ่อแม่'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: detail,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _dec('รายละเอียดเพิ่มเติม เช่น เลขที่บ้าน ชั้น จุดสังเกต'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check_rounded),
              label: const Text('บันทึกที่อยู่นี้', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }
}
