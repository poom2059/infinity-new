import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../data/auth/auth_user.dart';
import 'job_models.dart';
import 'job_store.dart';

const Color _kRed = Color(0xFFE3001B);

class JobChatScreen extends StatefulWidget {
  const JobChatScreen({super.key, required this.jobId, required this.accountUser});

  final String jobId;
  final AuthUser? accountUser;

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    JobStore.instance.addListener(_onStore);
  }

  void _onStore() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    JobStore.instance.removeListener(_onStore);
    _text.dispose();
    _scroll.dispose();
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

  void _send() {
    JobStore.instance.sendChat(widget.jobId, _userId(), _userName(), _text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final JobListing? job = JobStore.instance.listingById(widget.jobId);
    if (job == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: const Text('แชท')),
        body: const Center(child: Text('ไม่พบงาน')),
      );
    }

    final bool poster = job.posterId == _userId();
    final bool worker = job.chosenApplicantId == _userId();
    if (job.status != JobListingStatus.assigned || (!poster && !worker)) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: const Text('แชท')),
        body: const Center(child: Text('แชทได้หลังผู้ว่าจ้างเลือกผู้รับงานแล้วเท่านั้น')),
      );
    }

    final List<JobChatMessage> msgs = JobStore.instance.messagesFor(widget.jobId);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: _kRed,
        foregroundColor: Colors.white,
        title: Text('แชท · ${job.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: msgs.length,
              itemBuilder: (BuildContext context, int i) {
                final JobChatMessage m = msgs[i];
                final bool mine = m.senderId == _userId();
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                    decoration: BoxDecoration(
                      color: mine ? _kRed.withValues(alpha: 0.18) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.senderLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(m.text, style: const TextStyle(fontSize: 15, height: 1.35, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            elevation: 8,
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'พิมพ์ข้อความ…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _send,
                      style: IconButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
