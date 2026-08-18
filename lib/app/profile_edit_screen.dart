import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'avatar_frames.dart';
import '../data/auth/auth_repository.dart';
import '../data/profile/profile_store.dart';

/// หน้าปรับแต่งโปรไฟล์: เปลี่ยนรูป / ชื่อ / เบอร์โทร และยืนยันตัวตน (ไม่บังคับ)
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _avatarDataUrl;
  AvatarFrame _frame = AvatarFrame.none;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<ProfileStore>();
    _name = TextEditingController(text: store.name);
    _phone = TextEditingController(text: store.phone);
    _avatarDataUrl = store.avatarDataUrl;
    _frame = AvatarFrameInfo.fromId(store.avatarFrameId);
    _name.addListener(_markDirty);
    _phone.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<String?> _pickImageAsDataUrl({
    required ImageSource source,
    int maxWidth = 1200,
    int maxBytes = 850000,
  }) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        imageQuality: 80,
      );
      if (x == null) {
        return null;
      }
      final bytes = await x.readAsBytes();
      if (bytes.length > maxBytes) {
        _toast('ไฟล์ใหญ่เกินไป — ลองรูปที่เล็กลง');
        return null;
      }
      final mime = _mimeFromBytes(bytes);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (e) {
      _toast('เลือกรูปไม่สำเร็จ: $e');
      return null;
    }
  }

  Future<void> _changeAvatar() async {
    final source = await _chooseSource();
    if (source == null) {
      return;
    }
    final dataUrl = await _pickImageAsDataUrl(source: source, maxWidth: 720);
    if (dataUrl == null || !mounted) {
      return;
    }
    setState(() {
      _avatarDataUrl = dataUrl;
      _dirty = true;
    });
  }

  /// เลือกแหล่งรูป: กล้อง หรือคลังภาพในเครื่อง
  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
                title: const Text('เลือกจากคลังภาพ', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
                title: const Text('ถ่ายรูปใหม่', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ProfileStore>().updateProfile(
            name: _name.text,
            phone: _phone.text,
            avatarDataUrl: _avatarDataUrl ?? '',
            frameId: _frame.id,
          );
      try {
        await context.read<AuthRepository>().updateProfile(
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              avatarUrl: _avatarDataUrl ?? '',
              avatarFrame: _frame.id,
            );
      } catch (_) {
        // เซิร์ฟเวอร์ล่มชั่วคราว — ค่าในเครื่องถูกบันทึกแล้ว จะซิงก์ใหม่ตอนรีเฟรช
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _toast('บันทึกโปรไฟล์แล้ว');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('บันทึกไม่สำเร็จ: $e');
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProfileStore>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.topBar,
        foregroundColor: AppColors.topBarFg,
        title: const Text('แก้ไขโปรไฟล์', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  _AvatarPicker(
                    dataUrl: _avatarDataUrl,
                    frame: _frame,
                    onTap: _changeAvatar,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _changeAvatar,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('เปลี่ยนรูปโปรไฟล์'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                  if (_avatarDataUrl != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _avatarDataUrl = null;
                        _dirty = true;
                      }),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                      child: const Text('ลบรูปโปรไฟล์'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _FieldLabel('เลือกกรอบรูป'),
            const SizedBox(height: 10),
            _FrameSelector(
              selected: _frame,
              avatarDataUrl: _avatarDataUrl,
              onSelected: (AvatarFrame f) => setState(() {
                _frame = f;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            _FieldLabel('ชื่อที่แสดง'),
            const SizedBox(height: 8),
            _InputField(
              controller: _name,
              hint: 'เช่น สมชาย ใจดี',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            _FieldLabel('เบอร์โทรศัพท์'),
            const SizedBox(height: 8),
            _InputField(
              controller: _phone,
              hint: 'เช่น 0812345678',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            _VerificationCard(
              status: store.verificationStatus,
              hasIdCard: store.idCardDataUrl != null,
              hasFace: store.faceDataUrl != null,
              pickImage: _pickImageAsDataUrl,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: (_saving || !_dirty) ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('บันทึก', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.dataUrl, required this.frame, required this.onTap});

  final String? dataUrl;
  final AvatarFrame frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FramedAvatar(
            size: 124,
            frame: frame,
            child: avatarContent(dataUrl),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.canvas, width: 2),
              ),
              child: const Icon(Icons.photo_camera_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// เนื้อหารูปโปรไฟล์ (รูปจริง หรือไอคอนแทน) สำหรับใส่ใน [FramedAvatar]
Widget avatarContent(String? dataUrl) {
  if (dataUrl != null && dataUrl.isNotEmpty) {
    return Image.memory(
      _decode(dataUrl),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _avatarPlaceholder(),
    );
  }
  return _avatarPlaceholder();
}

Widget _avatarPlaceholder() {
  return Container(
    color: AppColors.accentSoft,
    alignment: Alignment.center,
    child: const Icon(Icons.person_rounded, size: 52, color: Color(0xFFE3001B)),
  );
}

/// แถบเลือกกรอบรูปแบบเลื่อนแนวนอน พร้อมพรีวิวรูปจริง
class _FrameSelector extends StatelessWidget {
  const _FrameSelector({
    required this.selected,
    required this.avatarDataUrl,
    required this.onSelected,
  });

  final AvatarFrame selected;
  final String? avatarDataUrl;
  final ValueChanged<AvatarFrame> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AvatarFrame.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int i) {
          final AvatarFrame f = AvatarFrame.values[i];
          final bool isSel = f == selected;
          return GestureDetector(
            onTap: () => onSelected(f),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? AppColors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: FramedAvatar(
                    size: 60,
                    frame: f,
                    gapColor: AppColors.surface,
                    child: avatarContent(avatarDataUrl),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  f.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                    color: isSel ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.status,
    required this.hasIdCard,
    required this.hasFace,
    required this.pickImage,
  });

  final IdVerificationStatus status;
  final bool hasIdCard;
  final bool hasFace;
  final Future<String?> Function({
    required ImageSource source,
    int maxWidth,
    int maxBytes,
  }) pickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ยืนยันตัวตน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'ยืนยันด้วยบัตรประชาชนและใบหน้า เพื่อปลดล็อกวงเงินและบริการเพิ่มเติม — จะยืนยันหรือไม่ก็ได้',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          _VerifyTile(
            icon: Icons.badge_outlined,
            title: 'สแกนบัตรประชาชน',
            done: hasIdCard,
          ),
          const SizedBox(height: 10),
          _VerifyTile(
            icon: Icons.face_retouching_natural_outlined,
            title: 'ยืนยันด้วยใบหน้า',
            done: hasFace,
          ),
          const SizedBox(height: 14),
          if (status.isVerified)
            OutlinedButton.icon(
              onPressed: () => context.read<ProfileStore>().clearVerification(),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('ยกเลิกการยืนยัน'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(46),
              ),
            )
          else
            FilledButton.icon(
              onPressed: () => _runVerification(context),
              icon: const Icon(Icons.verified_outlined, size: 20),
              label: const Text('เริ่มยืนยันตัวตน', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runVerification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<ProfileStore>();

    messenger.showSnackBar(const SnackBar(content: Text('ขั้นที่ 1/2 — ถ่าย/เลือกรูปบัตรประชาชน')));
    final idCard = await pickImage(source: ImageSource.camera, maxWidth: 1600);
    if (idCard == null) {
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('ขั้นที่ 2/2 — ถ่ายรูปใบหน้าเพื่อยืนยัน')));
    final face = await pickImage(source: ImageSource.camera, maxWidth: 1200);
    if (face == null) {
      return;
    }

    await store.submitVerification(idCardDataUrl: idCard, faceDataUrl: face);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('ยืนยันตัวตนสำเร็จ'),
        backgroundColor: Color(0xFF1B7E3C),
      ),
    );
  }
}

class _VerifyTile extends StatelessWidget {
  const _VerifyTile({required this.icon, required this.title, required this.done});

  final IconData icon;
  final String title;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 22,
          color: done ? const Color(0xFF2ECC71) : AppColors.textMuted,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final IdVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final bool verified = status.isVerified;
    final Color color = verified ? const Color(0xFF2ECC71) : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

Uint8List _decode(String dataUrl) {
  final i = dataUrl.indexOf(',');
  final b64 = i >= 0 ? dataUrl.substring(i + 1) : dataUrl;
  return base64Decode(b64);
}

String _mimeFromBytes(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  return 'image/jpeg';
}
