import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/auth/auth_user.dart';
import 'job_content_policy.dart';
import 'job_models.dart';
import 'job_store.dart';

const Color _kRed = Color(0xFFE3001B);

/// โพสงานจ้าง — เก็บมัดจำ 50% (สาธิต)
class JobPostScreen extends StatefulWidget {
  const JobPostScreen({super.key, required this.accountUser});

  final AuthUser? accountUser;

  @override
  State<JobPostScreen> createState() => _JobPostScreenState();
}

class _JobPostScreenState extends State<JobPostScreen> {
  final _title = TextEditingController();
  final _profession = TextEditingController();
  final _description = TextEditingController();
  final _storePhone = TextEditingController();
  final _storeAddress = TextEditingController();
  final _total = TextEditingController(text: '2000');
  final _ageMin = TextEditingController(text: '18');
  final _ageMax = TextEditingController(text: '55');
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  JobWorkerGenderPreference _genderPref = JobWorkerGenderPreference.any;
  bool _policyOk = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _profession.dispose();
    _description.dispose();
    _storePhone.dispose();
    _storeAddress.dispose();
    _total.dispose();
    _ageMin.dispose();
    _ageMax.dispose();
    super.dispose();
  }

  String _posterId() {
    final AuthUser? u = widget.accountUser;
    if (u != null && u.id.isNotEmpty) {
      return u.id;
    }
    return 'demo_user';
  }

  String _posterName() {
    final AuthUser? u = widget.accountUser;
    if (u != null && u.name.isNotEmpty) {
      return u.name;
    }
    return 'สมาชิกสาธิต';
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  int _digitCount(String s) => RegExp(r'\d').allMatches(s).length;

  Future<void> _pickStart() async {
    final TimeOfDay? p = await showTimePicker(context: context, initialTime: _start);
    if (p != null) {
      setState(() => _start = p);
    }
  }

  Future<void> _pickEnd() async {
    final TimeOfDay? p = await showTimePicker(context: context, initialTime: _end);
    if (p != null) {
      setState(() => _end = p);
    }
  }

  Future<void> _submit() async {
    final String title = _title.text.trim();
    final String profession = _profession.text.trim();
    final String description = _description.text.trim();
    final String storePhone = _storePhone.text.trim();
    final String storeAddress = _storeAddress.text.trim();
    final int? total = int.tryParse(_total.text.trim().replaceAll(',', ''));
    final int? ageMin = int.tryParse(_ageMin.text.trim());
    final int? ageMax = int.tryParse(_ageMax.text.trim());

    if (title.isEmpty || profession.isEmpty || description.isEmpty) {
      _toast('กรอกหัวข้อ อาชีพ/งาน และรายละเอียดให้ครบ');
      return;
    }
    if (storePhone.isEmpty || storeAddress.isEmpty) {
      _toast('กรอกเบอร์โทรร้านและสถานที่ตั้งของร้านให้ครบ');
      return;
    }
    if (_digitCount(storePhone) < 9) {
      _toast('เบอร์โทรร้านควรมีตัวเลขอย่างน้อย 9 หลัก');
      return;
    }
    if (jobTextViolatesPolicy('$title $profession $description $storePhone $storeAddress')) {
      _toast('เนื้อหานี้ไม่สามารถโพสได้ (ห้ามขายบริการหรือเนื้อหา 18+)');
      return;
    }
    if (!_policyOk) {
      _toast('กรุณายืนยันข้อกำหนดด้านล่าง');
      return;
    }
    if (total == null || total < 100) {
      _toast('ระบุค่าจ้างรวมอย่างน้อย ฿100');
      return;
    }
    if (ageMin == null || ageMax == null || ageMin < 15 || ageMax > 99 || ageMin > ageMax) {
      _toast('ตรวจสอบช่วงอายุที่รับ (เช่น 18–55)');
      return;
    }

    final int half = (total / 2).ceil();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('ยืนยันการโพสและมัดจำ 50%'),
          content: Text(
            'ค่าจ้างรวม ฿$total\n'
            'เพศผู้รับงาน: ${_genderPref.labelTh}\n'
            'เบอร์โทรร้าน: $storePhone\n'
            'ที่อยู่ร้าน: $storeAddress\n'
            'ระบบจะเก็บมัดจำครึ่งหนึ่ง (฿$half) จากบัญชีสาธิตของคุณก่อนเผยแพร่งาน\n'
            '(ในเวอร์ชันจริงจะหักผ่านระบบชำระเงิน)',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kRed),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final JobListing listing = JobListing(
      id: 'job_${DateTime.now().microsecondsSinceEpoch}',
      posterId: _posterId(),
      posterName: _posterName(),
      title: title,
      profession: profession,
      description: description,
      workerGenderPreference: _genderPref,
      storePhone: storePhone,
      storeAddress: storeAddress,
      ageMin: ageMin,
      ageMax: ageMax,
      workStartMinutes: _minutes(_start),
      workEndMinutes: _minutes(_end),
      totalBaht: total,
      createdAt: DateTime.now(),
    );
    JobStore.instance.addListing(listing);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('โพสงานแล้ว — เก็บมัดจำ ฿$half (สาธิต)'),
        backgroundColor: _kRed,
      ),
    );
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final int? total = int.tryParse(_total.text.trim().replaceAll(',', ''));
    final int half = total != null ? (total / 2).ceil() : 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: _kRed,
        foregroundColor: Colors.white,
        title: const Text('โพสงานจ้าง'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'รับทุกอาชีพยกเว้นการขายบริการและเนื้อหา 18+',
            style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'หัวข้องาน',
              hintText: 'เช่น ต้องการช่างซ่อมแอร์ 1 วัน',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _profession,
            decoration: const InputDecoration(
              labelText: 'อาชีพ / ประเภทงาน',
              hintText: 'เช่น ช่างแอร์ ช่างไฟ โปรแกรมเมอร์',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'รายละเอียดงาน',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          const Text('การเลือกเพศของผู้รับงาน', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'ระบุเพศของผู้ที่จะมารับงานตามความเหมาะสมของงาน (เช่น งานที่ต้องการแรงงานเฉพาะเพศ)',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SegmentedButton<JobWorkerGenderPreference>(
            segments: const <ButtonSegment<JobWorkerGenderPreference>>[
              ButtonSegment<JobWorkerGenderPreference>(
                value: JobWorkerGenderPreference.any,
                label: Text('ไม่จำกัด'),
              ),
              ButtonSegment<JobWorkerGenderPreference>(
                value: JobWorkerGenderPreference.maleOnly,
                label: Text('ผู้ชาย'),
              ),
              ButtonSegment<JobWorkerGenderPreference>(
                value: JobWorkerGenderPreference.femaleOnly,
                label: Text('ผู้หญิง'),
              ),
            ],
            selected: <JobWorkerGenderPreference>{_genderPref},
            onSelectionChanged: (Set<JobWorkerGenderPreference> next) {
              setState(() => _genderPref = next.first);
            },
          ),
          const SizedBox(height: 18),
          const Text('อายุของผู้รับงาน (ช่วง)', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageMin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ต่ำสุด'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageMax,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'สูงสุด'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('เวลาทำงาน (โดยประมาณ)', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickStart,
                  child: Text('เริ่ม ${_start.format(context)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEnd,
                  child: Text('จบ ${_end.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('ข้อมูลร้าน / สถานที่ทำงาน', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _storePhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทรร้าน',
              hintText: 'เช่น 02-123-4567 หรือ 0812345678',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _storeAddress,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'สถานที่ตั้งของร้าน',
              hintText: 'ที่อยู่เต็ม แขวง/เขต จังหวัด หรือจุดสังเกตให้ผู้รับงานเดินทางได้',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ค่าจ้างรวม (บาท)',
              prefixText: '฿ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (total != null && total >= 100)
            Text(
              'มัดจำ 50% ที่จะถูกเก็บเมื่อโพส: ฿$half',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _kRed),
            ),
          const SizedBox(height: 18),
          CheckboxListTile(
            value: _policyOk,
            onChanged: (bool? v) => setState(() => _policyOk = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'ยืนยันว่างานนี้ไม่ใช่การขายบริการทางเพศหรือเนื้อหา 18+',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('โพสงานและชำระมัดจำ 50%', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
