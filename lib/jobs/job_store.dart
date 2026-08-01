import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/api/infinity_api_client.dart';
import 'job_models.dart';

/// เก็บรายการงานผ่าน API
class JobStore extends ChangeNotifier {
  JobStore._();

  static final JobStore instance = JobStore._();

  InfinityApiClient? _client;
  final List<JobListing> _listings = [];
  final Map<String, List<JobChatMessage>> _messagesByJobId = HashMap();

  void attachClient(InfinityApiClient client) {
    _client = client;
  }

  UnmodifiableListView<JobListing> get listings => UnmodifiableListView(_listings);

  List<JobChatMessage> messagesFor(String jobId) =>
      UnmodifiableListView(List<JobChatMessage>.from(_messagesByJobId[jobId] ?? const []));

  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    final data = await client.getJson('/v1/jobs') as Map<String, dynamic>;
    final list = data['jobs'] as List<dynamic>? ?? [];
    _listings
      ..clear()
      ..addAll(list.map((e) => JobListing.fromApi(e as Map<String, dynamic>)));
    notifyListeners();
  }

  /// คืน `{jobId, escrowIntentId}`
  Future<({String jobId, String? escrowIntentId})> addListing(
    JobListing listing, {
    bool createEscrow = true,
  }) async {
    final client = _client;
    if (client == null) {
      _listings.insert(0, listing);
      notifyListeners();
      return (jobId: listing.id, escrowIntentId: null);
    }
    final data = await client.postJson('/v1/jobs', {
      'title': listing.title,
      'profession': listing.profession,
      'description': listing.description,
      'total_baht': listing.totalBaht,
      'age_min': listing.ageMin,
      'age_max': listing.ageMax,
      'work_time_label': listing.workTimeLabel,
      'store_phone': listing.storePhone,
      'store_address': listing.storeAddress,
      'contact_phone': listing.contactPhone,
      'worker_gender': listing.workerGenderPreference.name,
      'create_escrow': createEscrow,
    }) as Map<String, dynamic>;
    await refresh();
    final job = data['job'] as Map<String, dynamic>?;
    final jobId = '${job?['id'] ?? ''}';
    final escrow = data['escrow_intent_id'];
    return (
      jobId: jobId,
      escrowIntentId: escrow == null ? null : '$escrow',
    );
  }

  Future<void> publishAfterEscrow(String jobId) async {
    final client = _client;
    if (client == null) return;
    await client.postJson('/v1/jobs/$jobId/publish', {});
    await refresh();
  }

  bool userAlreadyApplied(JobListing listing, String userId) {
    for (final JobApplicant a in listing.applicants) {
      if (a.id == userId) return true;
    }
    return false;
  }

  Future<void> apply(String jobId, String userId, String displayName) async {
    final client = _client;
    if (client == null) return;
    await client.postJson('/v1/jobs/$jobId/apply', {});
    await refresh();
  }

  Future<void> assignWorker(String jobId, String applicantId) async {
    final client = _client;
    if (client == null) return;
    await client.postJson('/v1/jobs/$jobId/assign', {'applicant_user_id': applicantId});
    await refresh();
  }

  Future<void> loadMessages(String jobId) async {
    final client = _client;
    if (client == null) return;
    final data = await client.getJson('/v1/jobs/$jobId/messages') as Map<String, dynamic>;
    final list = data['messages'] as List<dynamic>? ?? [];
    _messagesByJobId[jobId] = list.map((e) {
      final m = e as Map<String, dynamic>;
      return JobChatMessage(
        id: '${m['id']}',
        senderId: '${m['sender_id']}',
        senderLabel: '${m['sender_label']}',
        text: '${m['text']}',
        sentAt: DateTime.tryParse('${m['sent_at']}') ?? DateTime.now(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> sendChat(String jobId, String senderId, String senderLabel, String text) async {
    final client = _client;
    if (client == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await client.postJson('/v1/jobs/$jobId/messages', {'text': trimmed});
    await loadMessages(jobId);
  }

  JobListing? listingById(String id) {
    for (final JobListing j in _listings) {
      if (j.id == id) return j;
    }
    return null;
  }
}
