import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// สถานะการยืนยันตัวตน (สแกนบัตร + ใบหน้า) — เป็นทางเลือก ไม่บังคับ
enum IdVerificationStatus { none, pending, verified }

extension IdVerificationStatusInfo on IdVerificationStatus {
  String get label {
    switch (this) {
      case IdVerificationStatus.none:
        return 'ยังไม่ยืนยัน';
      case IdVerificationStatus.pending:
        return 'กำลังตรวจสอบ';
      case IdVerificationStatus.verified:
        return 'ยืนยันแล้ว';
    }
  }

  bool get isVerified => this == IdVerificationStatus.verified;
}

/// เก็บข้อมูลโปรไฟล์ที่ผู้ใช้ปรับแต่งได้ และบันทึกลง [SharedPreferences]
///
/// รูปภาพถูกเก็บเป็น data URL (base64) เพื่อให้ทำงานได้ทั้งบนเว็บและมือถือ
class ProfileStore extends ChangeNotifier {
  ProfileStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  static const String _kName = 'profile_name';
  static const String _kPhone = 'profile_phone';
  static const String _kAvatar = 'profile_avatar';
  static const String _kIdCard = 'profile_id_card';
  static const String _kFace = 'profile_face';
  static const String _kStatus = 'profile_verify_status';
  static const String _kFrame = 'profile_avatar_frame';

  String _name = '';
  String _phone = '';
  String? _avatarDataUrl;
  String? _idCardDataUrl;
  String? _faceDataUrl;
  IdVerificationStatus _status = IdVerificationStatus.none;
  String _frameId = 'none';

  String get name => _name;
  String get phone => _phone;
  String? get avatarDataUrl => _avatarDataUrl;

  /// รหัสกรอบรูปที่เลือก (ดูค่าได้จาก AvatarFrame)
  String get avatarFrameId => _frameId;
  String? get idCardDataUrl => _idCardDataUrl;
  String? get faceDataUrl => _faceDataUrl;
  IdVerificationStatus get verificationStatus => _status;
  bool get hasAvatar => _avatarDataUrl != null && _avatarDataUrl!.isNotEmpty;

  void _load() {
    _name = _prefs.getString(_kName) ?? '';
    _phone = _prefs.getString(_kPhone) ?? '';
    _avatarDataUrl = _prefs.getString(_kAvatar);
    _idCardDataUrl = _prefs.getString(_kIdCard);
    _faceDataUrl = _prefs.getString(_kFace);
    final s = _prefs.getString(_kStatus);
    _status = IdVerificationStatus.values.firstWhere(
      (IdVerificationStatus e) => e.name == s,
      orElse: () => IdVerificationStatus.none,
    );
    _frameId = _prefs.getString(_kFrame) ?? 'none';
  }

  /// เติมค่าเริ่มต้นจากบัญชีที่ล็อกอิน — เฉพาะช่องที่ผู้ใช้ยังไม่เคยตั้งเอง
  void seedFromAccount({String? name, String? phone}) {
    var changed = false;
    if (_name.isEmpty && (name?.trim().isNotEmpty ?? false)) {
      _name = name!.trim();
      changed = true;
    }
    if (_phone.isEmpty && (phone?.trim().isNotEmpty ?? false)) {
      _phone = phone!.trim();
      changed = true;
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? name, String? phone, String? avatarDataUrl, String? frameId}) async {
    if (name != null) {
      _name = name.trim();
    }
    if (phone != null) {
      _phone = phone.trim();
    }
    if (avatarDataUrl != null) {
      _avatarDataUrl = avatarDataUrl.isEmpty ? null : avatarDataUrl;
    }
    if (frameId != null) {
      _frameId = frameId;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setAvatar(String? dataUrl) async {
    _avatarDataUrl = (dataUrl == null || dataUrl.isEmpty) ? null : dataUrl;
    await _persist();
    notifyListeners();
  }

  /// ส่งข้อมูลยืนยันตัวตน (เดโม: อนุมัติทันที) — ผู้ใช้จะยืนยันหรือไม่ก็ได้
  Future<void> submitVerification({
    required String idCardDataUrl,
    required String faceDataUrl,
  }) async {
    _idCardDataUrl = idCardDataUrl;
    _faceDataUrl = faceDataUrl;
    _status = IdVerificationStatus.verified;
    await _persist();
    notifyListeners();
  }

  Future<void> clearVerification() async {
    _idCardDataUrl = null;
    _faceDataUrl = null;
    _status = IdVerificationStatus.none;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(_kName, _name);
    await _prefs.setString(_kPhone, _phone);
    await _writeOrRemove(_kAvatar, _avatarDataUrl);
    await _writeOrRemove(_kIdCard, _idCardDataUrl);
    await _writeOrRemove(_kFace, _faceDataUrl);
    await _prefs.setString(_kStatus, _status.name);
    await _prefs.setString(_kFrame, _frameId);
  }

  Future<void> _writeOrRemove(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}
