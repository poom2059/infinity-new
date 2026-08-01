import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/auth/auth_user.dart';
import 'job_chat_screen.dart';
import 'job_models.dart';
import 'job_store.dart';

const Color _kRed = Color(0xFFE3001B);

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId, required this.accountUser});

  final String jobId;
  final AuthUser? accountUser;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  @override
  void initState() {
    super.initState();
    JobStore.instance.addListener(_onStore);
  }

  void _onStore() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    JobStore.instance.removeListener(_onStore);
    super.dispose();
  }

  String _userId() {
    final AuthUser? u = widget.accountUser;
    if (u != null && u.id.isNotEmpty) {
      return u.id;
    }
    return 'demo_user';
  }

  String _userName() {
    final AuthUser? u = widget.accountUser;
    if (u != null && u.name.isNotEmpty) {
      return u.name;
    }
    return 'สมาชิกสาธิต';
  }

  bool _isPoster(JobListing j) => j.posterId == _userId();

  bool _isChosenWorker(JobListing j) => j.chosenApplicantId == _userId();

  void _openChat(JobListing j) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobChatScreen(
          jobId: j.id,
          accountUser: widget.accountUser,
        ),
      ),
    );
  }

  void _apply(JobListing j) {
    JobStore.instance.apply(j.id, _userId(), _userName());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คุณกดรับงานแล้ว — ผู้ว่าจ้างจะเห็นในรายการผู้สมัคร')),
    );
  }

  Future<void> _pickWorker(JobListing j, JobApplicant a) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('เลือกผู้รับงาน'),
          content: Text('ยืนยันให้ ${a.displayName} เป็นผู้รับงานนี้?'),
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
    JobStore.instance.assignWorker(j.id, a.id);
    if (!mounted) {
      return;
    }
    final String poster = j.posterName;
    final String worker = a.displayName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'แจ้งเตือนผู้ว่าจ้าง ($poster): เลือก $worker แล้ว\n'
          'แจ้งเตือนผู้รับงาน ($worker): คุณได้รับเลือกให้ทำงาน',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JobListing? j = JobStore.instance.listingById(widget.jobId);
    if (j == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: const Text('งาน')),
        body: const Center(child: Text('ไม่พบงานนี้')),
      );
    }

    final bool poster = _isPoster(j);
    final bool chosen = _isChosenWorker(j);
    final bool canChat = j.status == JobListingStatus.assigned && (poster || chosen);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: _kRed,
        foregroundColor: Colors.white,
        title: const Text('รายละเอียดงาน'),
        actions: [
          if (canChat)
            IconButton(
              tooltip: 'แชท',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => _openChat(j),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(j.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.2, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            j.profession,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _tile(Icons.person_outline_rounded, 'ผู้ว่าจ้าง', j.posterName),
          _tile(Icons.wc_rounded, 'เพศของผู้รับงาน', j.workerGenderPreference.labelTh),
          _tile(Icons.cake_outlined, 'อายุผู้รับงาน', '${j.ageMin} – ${j.ageMax} ปี'),
          _tile(Icons.schedule_rounded, 'เวลาทำงาน', j.workTimeLabel),
          _tile(Icons.phone_in_talk_outlined, 'เบอร์โทรร้าน', j.storePhone),
          _tile(Icons.storefront_outlined, 'สถานที่ตั้งของร้าน', j.storeAddress),
          if (j.contactPhone.isNotEmpty)
            _tile(Icons.phone_outlined, 'เบอร์ติดต่อ', j.contactPhone),
          _tile(Icons.payments_outlined, 'ค่าจ้างรวม', '฿${j.totalBaht}'),
          _tile(Icons.savings_outlined, 'มัดจำ 50% (สาธิต)', '฿${j.escrowHalfBaht}'),
          const SizedBox(height: 16),
          const Text('รายละเอียด', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(j.description, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 22),
          if (j.status == JobListingStatus.open && !poster) ...[
            if (JobStore.instance.userAlreadyApplied(j, _userId()))
              const Text('คุณกดรับงานแล้ว — รอผู้ว่าจ้างเลือก', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))
            else
              FilledButton(
                onPressed: () => _apply(j),
                style: FilledButton.styleFrom(backgroundColor: _kRed, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('รับงาน', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
          if (j.status == JobListingStatus.open && poster && j.applicants.isNotEmpty) ...[
            const Divider(height: 32),
            const Text('ผู้กดรับงาน (เลือกคนทำงาน)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ...j.applicants.map(
              (JobApplicant a) => Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(a.displayName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  subtitle: Text('กดรับเมื่อ ${_formatTime(a.appliedAt)}', style: const TextStyle(color: AppColors.textMuted)),
                  trailing: FilledButton(
                    onPressed: () => _pickWorker(j, a),
                    style: FilledButton.styleFrom(backgroundColor: _kRed),
                    child: const Text('เลือก'),
                  ),
                ),
              ),
            ),
          ],
          if (j.status == JobListingStatus.open && poster && j.applicants.isEmpty)
            Text('ยังไม่มีผู้กดรับงาน', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          if (j.status == JobListingStatus.assigned) ...[
            const Divider(height: 32),
            Text(
              'ผู้รับงาน: ${j.chosenApplicant?.displayName ?? "—"}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            if (canChat)
              OutlinedButton.icon(
                onPressed: () => _openChat(j),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('แชทกับอีกฝ่าย'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _formatTime(DateTime d) {
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static Widget _tile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
