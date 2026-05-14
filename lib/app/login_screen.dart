import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'ui_strings_th.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_user.dart';
import '../data/push/push_registration_repository.dart';
import '../config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final void Function(AuthUser user) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '0810000000');
  final _code = TextEditingController(text: '123456');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthRepository>();
      final push = context.read<PushRegistrationRepository>();
      await auth.requestOtp(_phone.text.trim());
      final user = await auth.verifyOtp(phone: _phone.text.trim(), code: _code.text.trim());
      await push.registerDeviceToken(AppConfig.fcmDemoToken);
      if (!mounted) {
        return;
      }
      widget.onLoggedIn(user);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SplashTheme.overlay(),
      child: Scaffold(
        backgroundColor: SplashTheme.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      UiStringsTh.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: SplashTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ล็อกอินด้วยเบอร์โทร (รหัสยืนยัน 6 หลักใดก็ได้เมื่อเชื่อมเซิร์ฟเวอร์)\n'
                      'ผู้ดูแลระบบ: 0810000000 หรือ 0888888888',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14, height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: SplashTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'เบอร์โทร',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE3001B))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: SplashTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'รหัสยืนยัน 6 หลัก',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE3001B))),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('เข้าสู่ระบบ', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
