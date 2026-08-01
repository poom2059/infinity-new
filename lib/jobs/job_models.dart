// โมเดลงานจ้าง

/// เพศของผู้รับงานที่ผู้ว่าจ้างต้องการ
enum JobWorkerGenderPreference {
  any,
  maleOnly,
  femaleOnly,
}

extension JobWorkerGenderPreferenceX on JobWorkerGenderPreference {
  String get labelTh {
    switch (this) {
      case JobWorkerGenderPreference.any:
        return 'ไม่จำกัดเพศ';
      case JobWorkerGenderPreference.maleOnly:
        return 'เฉพาะผู้ชาย';
      case JobWorkerGenderPreference.femaleOnly:
        return 'เฉพาะผู้หญิง';
    }
  }
}

enum JobListingStatus {
  /// เปิดรับผู้สมัครหลายคน
  open,

  /// ผู้โพสเลือกผู้รับงานแล้ว
  assigned,

  closed,
  pendingPayment,
}

/// เพศของผู้รับงานที่ต้องการ
enum JobGender { any, male, female }

extension JobGenderInfo on JobGender {
  String get label {
    switch (this) {
      case JobGender.any:
        return 'ทุกเพศ';
      case JobGender.male:
        return 'ชาย';
      case JobGender.female:
        return 'หญิง';
    }
  }
}

class JobApplicant {
  const JobApplicant({
    required this.id,
    required this.displayName,
    required this.appliedAt,
  });

  final String id;
  final String displayName;
  final DateTime appliedAt;
}

class JobChatMessage {
  const JobChatMessage({
    required this.id,
    required this.senderId,
    required this.senderLabel,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String senderLabel;
  final String text;
  final DateTime sentAt;
}

class JobListing {
  JobListing({
    required this.id,
    required this.posterId,
    required this.posterName,
    required this.title,
    required this.profession,
    required this.description,
    required this.workerGenderPreference,
    required this.storePhone,
    required this.storeAddress,
    required this.ageMin,
    required this.ageMax,
    required this.workStartMinutes,
    required this.workEndMinutes,
    required this.totalBaht,
    required this.createdAt,
    this.genderPreference = JobGender.any,
    this.contactPhone = '',
    this.status = JobListingStatus.open,
    List<JobApplicant>? applicants,
    this.chosenApplicantId,
  }) : applicants = applicants ?? [];

  final String id;
  final String posterId;
  final String posterName;
  final String title;
  final String profession;
  final String description;
  final JobWorkerGenderPreference workerGenderPreference;
  /// เบอร์โทรติดต่อร้าน / ผู้ว่าจ้าง
  final String storePhone;
  /// สถานที่ตั้งร้าน / ที่อยู่ทำงาน
  final String storeAddress;
  final int ageMin;
  final int ageMax;
  final int workStartMinutes;
  final int workEndMinutes;
  final int totalBaht;
  final DateTime createdAt;
  final JobGender genderPreference;
  final String contactPhone;
  JobListingStatus status;
  List<JobApplicant> applicants;
  String? chosenApplicantId;

  int get escrowHalfBaht => (totalBaht / 2).ceil();

  String get workTimeLabel {
    String two(int m) {
      final h = m ~/ 60;
      final min = m % 60;
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }

    return '${two(workStartMinutes)} – ${two(workEndMinutes)}';
  }

  JobApplicant? get chosenApplicant {
    if (chosenApplicantId == null) {
      return null;
    }
    for (final JobApplicant a in applicants) {
      if (a.id == chosenApplicantId) {
        return a;
      }
    }
    return null;
  }

  factory JobListing.fromApi(Map<String, dynamic> j) {
    final genderRaw = '${j['worker_gender'] ?? 'any'}';
    final JobWorkerGenderPreference gender = switch (genderRaw) {
      'maleOnly' || 'male' => JobWorkerGenderPreference.maleOnly,
      'femaleOnly' || 'female' => JobWorkerGenderPreference.femaleOnly,
      _ => JobWorkerGenderPreference.any,
    };
    final statusRaw = '${j['status'] ?? 'open'}';
    final JobListingStatus status = switch (statusRaw) {
      'assigned' => JobListingStatus.assigned,
      'closed' => JobListingStatus.closed,
      'pending_payment' => JobListingStatus.pendingPayment,
      _ => JobListingStatus.open,
    };
    final applicantsRaw = j['applicants'] as List<dynamic>? ?? [];
    final timeLabel = '${j['work_time_label'] ?? '09:00 – 18:00'}';
    final parts = timeLabel.split('–');
    int parseMin(String s) {
      final t = s.trim().split(':');
      if (t.length < 2) return 0;
      return (int.tryParse(t[0]) ?? 0) * 60 + (int.tryParse(t[1]) ?? 0);
    }

    return JobListing(
      id: '${j['id']}',
      posterId: '${j['poster_id']}',
      posterName: 'ผู้ว่าจ้าง',
      title: '${j['title']}',
      profession: '${j['profession']}',
      description: '${j['description']}',
      workerGenderPreference: gender,
      storePhone: '${j['store_phone'] ?? ''}',
      storeAddress: '${j['store_address'] ?? ''}',
      ageMin: (j['age_min'] as num?)?.toInt() ?? 18,
      ageMax: (j['age_max'] as num?)?.toInt() ?? 60,
      workStartMinutes: parts.isNotEmpty ? parseMin(parts.first) : 9 * 60,
      workEndMinutes: parts.length > 1 ? parseMin(parts[1]) : 18 * 60,
      totalBaht: (j['total_baht'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      contactPhone: '${j['contact_phone'] ?? ''}',
      status: status,
      applicants: applicantsRaw.map((e) {
        final a = e as Map<String, dynamic>;
        return JobApplicant(
          id: '${a['id']}',
          displayName: '${a['display_name']}',
          appliedAt: DateTime.tryParse('${a['applied_at']}') ?? DateTime.now(),
        );
      }).toList(),
      chosenApplicantId: j['chosen_applicant_id'] == null ? null : '${j['chosen_applicant_id']}',
    );
  }
}
