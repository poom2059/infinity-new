import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/auth/auth_user.dart';
import 'job_detail_screen.dart';
import 'job_models.dart';
import 'job_post_screen.dart';
import 'job_store.dart';

const Color _kRed = Color(0xFFE3001B);

/// แท็บ Job — รายการงานจ้าง (สาธิต)
class JobHubTab extends StatefulWidget {
  const JobHubTab({super.key, required this.accountUser});

  final AuthUser? accountUser;

  @override
  State<JobHubTab> createState() => _JobHubTabState();
}

class _JobHubTabState extends State<JobHubTab> {
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

  Future<void> _openPost() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => JobPostScreen(accountUser: widget.accountUser),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _openDetail(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobDetailScreen(
          jobId: id,
          accountUser: widget.accountUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<JobListing> list = JobStore.instance.listings.toList();
    final double bottomPad = 88 + MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: AppColors.canvas,
      child: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            children: [
              const Text(
                'Job',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'โพสหางานทุกอาชีพ (ห้ามขายบริการและ 18+) — เก็บมัดจำ 50% เมื่อโพส รับงานได้หลายคน ผู้ว่าจ้างเลือกผู้รับงาน แล้วแชทได้',
                style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 18),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'ยังไม่มีงาน\nแตะปุ่มด้านล่างเพื่อโพสงานจ้าง',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w600, height: 1.5),
                    ),
                  ),
                )
              else
                ...list.map((JobListing j) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppColors.surface,
                      elevation: 1,
                      shadowColor: Colors.black45,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _openDetail(j.id),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      j.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _statusChip(j.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                j.profession,
                                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '฿${j.totalBaht} · อายุ ${j.ageMin}–${j.ageMax} ปี · ${j.workTimeLabel}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'โดย ${j.posterName}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: FloatingActionButton.extended(
              onPressed: _openPost,
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('โพสงาน', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusChip(JobListingStatus s) {
    final String label;
    final Color bg;
    final Color fg;
    switch (s) {
      case JobListingStatus.open:
        label = 'เปิดรับ';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
        break;
      case JobListingStatus.assigned:
        label = 'เลือกแล้ว';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF1B5E20);
        break;
      case JobListingStatus.closed:
        label = 'ปิด';
        bg = Color(0xFFECEEF2);
        fg = AppColors.textMuted;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: fg)),
    );
  }
}
