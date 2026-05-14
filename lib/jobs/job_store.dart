import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'job_models.dart';

/// เก็บรายการงานและแชทในแอป (สาธิต)
class JobStore extends ChangeNotifier {
  JobStore._();

  static final JobStore instance = JobStore._();

  final List<JobListing> _listings = [];
  final Map<String, List<JobChatMessage>> _messagesByJobId = HashMap();

  UnmodifiableListView<JobListing> get listings => UnmodifiableListView(_listings);

  List<JobChatMessage> messagesFor(String jobId) =>
      UnmodifiableListView(List<JobChatMessage>.from(_messagesByJobId[jobId] ?? const []));

  void addListing(JobListing listing) {
    _listings.insert(0, listing);
    _messagesByJobId[listing.id] = [];
    notifyListeners();
  }

  bool userAlreadyApplied(JobListing listing, String userId) {
    for (final JobApplicant a in listing.applicants) {
      if (a.id == userId) {
        return true;
      }
    }
    return false;
  }

  void apply(String jobId, String userId, String displayName) {
    final JobListing? j = _byId(jobId);
    if (j == null || j.status != JobListingStatus.open) {
      return;
    }
    if (j.posterId == userId) {
      return;
    }
    if (userAlreadyApplied(j, userId)) {
      return;
    }
    j.applicants = List<JobApplicant>.from(j.applicants)
      ..add(
        JobApplicant(
          id: userId,
          displayName: displayName,
          appliedAt: DateTime.now(),
        ),
      );
    notifyListeners();
  }

  void assignWorker(String jobId, String applicantId) {
    final JobListing? j = _byId(jobId);
    if (j == null || j.status != JobListingStatus.open) {
      return;
    }
    JobApplicant? found;
    for (final JobApplicant a in j.applicants) {
      if (a.id == applicantId) {
        found = a;
        break;
      }
    }
    if (found == null) {
      return;
    }
    j.chosenApplicantId = applicantId;
    j.status = JobListingStatus.assigned;
    notifyListeners();
  }

  void sendChat(String jobId, String senderId, String senderLabel, String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final List<JobChatMessage> list = _messagesByJobId.putIfAbsent(jobId, () => []);
    list.add(
      JobChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        senderId: senderId,
        senderLabel: senderLabel,
        text: trimmed,
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  JobListing? _byId(String id) {
    for (final JobListing j in _listings) {
      if (j.id == id) {
        return j;
      }
    }
    return null;
  }

  JobListing? listingById(String id) => _byId(id);
}
