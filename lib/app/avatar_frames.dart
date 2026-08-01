import 'package:flutter/material.dart';

/// กรอบรูปโปรไฟล์ที่เลือกได้ — วาดด้วยโค้ด (gradient ring + เรืองแสง) คมชัดทุกขนาด
enum AvatarFrame { none, ruby, gold, ocean, aurora, neon, platinum, sunset }

extension AvatarFrameInfo on AvatarFrame {
  String get id => name;

  String get label {
    switch (this) {
      case AvatarFrame.none:
        return 'ไม่มีกรอบ';
      case AvatarFrame.ruby:
        return 'ทับทิม';
      case AvatarFrame.gold:
        return 'ทองคำ';
      case AvatarFrame.ocean:
        return 'มหาสมุทร';
      case AvatarFrame.aurora:
        return 'ออโรรา';
      case AvatarFrame.neon:
        return 'นีออน';
      case AvatarFrame.platinum:
        return 'แพลทินัม';
      case AvatarFrame.sunset:
        return 'ตะวันตกดิน';
    }
  }

  static AvatarFrame fromId(String? id) {
    return AvatarFrame.values.firstWhere(
      (AvatarFrame f) => f.name == id,
      orElse: () => AvatarFrame.none,
    );
  }

  /// ชุดสีไล่เฉดของวงกรอบ (ไล่ตามเข็มนาฬิกา)
  List<Color> get ringColors {
    switch (this) {
      case AvatarFrame.none:
        return const <Color>[Color(0xFF343648), Color(0xFF343648)];
      case AvatarFrame.ruby:
        return const <Color>[
          Color(0xFFFF5E7E),
          Color(0xFFE3001B),
          Color(0xFF8E0014),
          Color(0xFFFF5E7E),
        ];
      case AvatarFrame.gold:
        return const <Color>[
          Color(0xFFFFF1A8),
          Color(0xFFFFD24A),
          Color(0xFFB8860B),
          Color(0xFFFFF1A8),
        ];
      case AvatarFrame.ocean:
        return const <Color>[
          Color(0xFF5EE7FF),
          Color(0xFF2E86FF),
          Color(0xFF0B3FA8),
          Color(0xFF5EE7FF),
        ];
      case AvatarFrame.aurora:
        return const <Color>[
          Color(0xFF36F1A6),
          Color(0xFF2EA8FF),
          Color(0xFFB07CFF),
          Color(0xFF36F1A6),
        ];
      case AvatarFrame.neon:
        return const <Color>[
          Color(0xFFFF2EC4),
          Color(0xFF7A2EFF),
          Color(0xFF2EE6FF),
          Color(0xFFFF2EC4),
        ];
      case AvatarFrame.platinum:
        return const <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFC7CCD8),
          Color(0xFF7E869B),
          Color(0xFFFFFFFF),
        ];
      case AvatarFrame.sunset:
        return const <Color>[
          Color(0xFFFFD86F),
          Color(0xFFFF8A3D),
          Color(0xFFFF3D77),
          Color(0xFFFFD86F),
        ];
    }
  }

  /// สีเรืองแสงรอบกรอบ
  Color get glowColor {
    switch (this) {
      case AvatarFrame.none:
        return Colors.transparent;
      case AvatarFrame.ruby:
        return const Color(0xFFE3001B);
      case AvatarFrame.gold:
        return const Color(0xFFFFD24A);
      case AvatarFrame.ocean:
        return const Color(0xFF2E86FF);
      case AvatarFrame.aurora:
        return const Color(0xFF36F1A6);
      case AvatarFrame.neon:
        return const Color(0xFFFF2EC4);
      case AvatarFrame.platinum:
        return const Color(0xFFC7CCD8);
      case AvatarFrame.sunset:
        return const Color(0xFFFF8A3D);
    }
  }

  bool get hasFrame => this != AvatarFrame.none;
}

/// แสดงรูปโปรไฟล์พร้อมกรอบที่เลือก (วงไล่เฉด + ช่องว่างสีเข้ม + เรืองแสง)
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({
    super.key,
    required this.size,
    required this.frame,
    required this.child,
    this.gapColor = const Color(0xFF13141A),
  });

  /// ขนาดรวมกรอบ (เส้นผ่านศูนย์กลางด้านนอก)
  final double size;
  final AvatarFrame frame;

  /// เนื้อหาด้านใน (เช่น รูปภาพ) จะถูกตัดเป็นวงกลม
  final Widget child;
  final Color gapColor;

  @override
  Widget build(BuildContext context) {
    if (!frame.hasFrame) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: child),
      );
    }

    final double thickness = (size * 0.07).clamp(3.0, 8.0);
    final double gap = (size * 0.025).clamp(1.5, 4.0);
    final double inner = size - 2 * thickness - 2 * gap;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: frame.ringColors),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: frame.glowColor.withValues(alpha: 0.45),
              blurRadius: size * 0.10,
              spreadRadius: size * 0.01,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(thickness),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: gapColor),
            child: Padding(
              padding: EdgeInsets.all(gap),
              child: ClipOval(
                child: SizedBox(width: inner, height: inner, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
