import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'social_login_buttons.dart';
import 'ui_strings_th.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/auth_user.dart';
import '../data/push/push_registration_repository.dart';
import '../services/device_push.dart';
import '../services/phone_auth.dart';
import '../services/social_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final void Function(AuthUser user) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  bool _useFirebase = false;
  String? _error;
  SocialProvider? _socialBusy;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _afterLogin(AuthUser user) async {
    final push = context.read<PushRegistrationRepository>();
    final token = await DevicePush.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await push.registerDeviceToken(token);
    }
    if (!mounted) return;
    widget.onLoggedIn(user);
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim();
      if (PhoneAuthService.instance.firebaseReady) {
        await PhoneAuthService.instance.requestOtp(PhoneAuthService.toE164(phone));
        _useFirebase = true;
      } else {
        final auth = context.read<AuthRepository>();
        await auth.requestOtp(phone);
        _useFirebase = false;
      }
      if (!mounted) return;
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งรหัสยืนยันไปยังเบอร์ของคุณแล้ว')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthRepository>();
      final AuthUser user;
      if (_useFirebase) {
        final idToken = await PhoneAuthService.instance.confirmOtp(_code.text.trim());
        user = await auth.loginWithFirebaseIdToken(idToken);
      } else {
        user = await auth.verifyOtp(
          phone: _phone.text.trim(),
          code: _code.text.trim(),
        );
      }
      await _afterLogin(user);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _socialLogin(SocialProvider provider) async {
    setState(() {
      _socialBusy = provider;
      _error = null;
    });
    try {
      final cred = await SocialAuth.signIn(provider);
      final auth = context.read<AuthRepository>();
      final user = await auth.loginWithSocial(
        provider.providerId,
        idToken: cred.idToken,
        accessToken: cred.accessToken,
      );
      await _afterLogin(user);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _socialBusy = null);
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
                      'เข้าสู่ระบบด้วยเบอร์โทรศัพท์\nระบบจะส่งรหัส OTP จริงไปยังเบอร์ของคุณ',
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
                    if (_otpSent)
                      TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: SplashTheme.text),
                        decoration: const InputDecoration(
                          labelText: 'รหัส OTP 6 หลัก',
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
                      onPressed: _busy ? null : (_otpSent ? _verifyOtp : _requestOtp),
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
                          : Text(
                              _otpSent ? 'ยืนยันรหัส OTP' : 'ขอรหัส OTP',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : _requestOtp,
                        child: const Text('ส่งรหัสอีกครั้ง', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SocialLoginButtons(
                      busyProvider: _socialBusy,
                      onProvider: (_busy || _socialBusy != null) ? (_) {} : _socialLogin,
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
