import 'package:flutter/material.dart';

/// ผู้ให้บริการล็อกอินภายนอกที่รองรับในหน้าเข้าสู่ระบบ
enum SocialProvider { google, facebook, line }

extension SocialProviderInfo on SocialProvider {
  String get label {
    switch (this) {
      case SocialProvider.google:
        return 'Google';
      case SocialProvider.facebook:
        return 'Facebook';
      case SocialProvider.line:
        return 'LINE';
    }
  }

  String get buttonText => 'ดำเนินการต่อด้วย $label';

  /// รหัสผู้ให้บริการที่ส่งให้เซิร์ฟเวอร์ (google / facebook / line)
  String get providerId => name;

  Color get background {
    switch (this) {
      case SocialProvider.google:
        return Colors.white;
      case SocialProvider.facebook:
        return const Color(0xFF1877F2);
      case SocialProvider.line:
        return const Color(0xFF06C755);
    }
  }

  Color get foreground {
    switch (this) {
      case SocialProvider.google:
        return const Color(0xFF1F1F1F);
      case SocialProvider.facebook:
      case SocialProvider.line:
        return Colors.white;
    }
  }
}

/// แถบปุ่มล็อกอินผ่านโซเชียล (Google / Facebook / LINE)
///
/// ส่ง [onProvider] เพื่อรับ event เมื่อกดปุ่มแต่ละราย และ [busyProvider]
/// เพื่อแสดงสปินเนอร์บนปุ่มที่กำลังทำงานอยู่
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    required this.onProvider,
    this.busyProvider,
    this.dividerColor = Colors.white24,
    this.dividerTextColor = Colors.white70,
  });

  final void Function(SocialProvider provider) onProvider;
  final SocialProvider? busyProvider;
  final Color dividerColor;
  final Color dividerTextColor;

  @override
  Widget build(BuildContext context) {
    final bool anyBusy = busyProvider != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'หรือเข้าสู่ระบบด้วย',
                style: TextStyle(color: dividerTextColor, fontSize: 13),
              ),
            ),
            Expanded(child: Divider(color: dividerColor)),
          ],
        ),
        const SizedBox(height: 16),
        for (final provider in SocialProvider.values) ...[
          _SocialButton(
            provider: provider,
            busy: busyProvider == provider,
            onPressed: anyBusy ? null : () => onProvider(provider),
          ),
          if (provider != SocialProvider.values.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.busy,
    required this.onPressed,
  });

  final SocialProvider provider;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: provider.background,
          foregroundColor: provider.foreground,
          disabledBackgroundColor: provider.background.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: provider == SocialProvider.google
                ? const BorderSide(color: Color(0xFFDADCE0))
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialGlyph(provider: provider),
            const SizedBox(width: 12),
            busy
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: provider.foreground,
                    ),
                  )
                : Text(
                    provider.buttonText,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ],
        ),
      ),
    );
  }
}

/// ไอคอนสัญลักษณ์ของแต่ละแบรนด์ (วาดเองโดยไม่ใช้ไฟล์ asset)
class _SocialGlyph extends StatelessWidget {
  const _SocialGlyph({required this.provider});

  final SocialProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider) {
      case SocialProvider.google:
        return const SizedBox(
          width: 22,
          height: 22,
          child: _GoogleG(),
        );
      case SocialProvider.facebook:
        return const Text(
          'f',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        );
      case SocialProvider.line:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'LINE',
            style: TextStyle(
              color: Color(0xFF06C755),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        );
    }
  }
}

/// ตัวอักษร "G" สี่สีของ Google แบบเรียบง่าย
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        height: 1,
        fontWeight: FontWeight.w900,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
