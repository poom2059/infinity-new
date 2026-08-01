import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../app/social_login_buttons.dart';
import '../config/app_config.dart';
import '../data/api/api_exception.dart';

class SocialAuthCredential {
  const SocialAuthCredential({this.idToken, this.accessToken});
  final String? idToken;
  final String? accessToken;
}

class SocialAuth {
  SocialAuth._();

  static Future<SocialAuthCredential> signIn(SocialProvider provider) async {
    switch (provider) {
      case SocialProvider.google:
        final webClientId = AppConfig.googleWebClientId;
        final serverClientId = AppConfig.googleServerClientId;
        final GoogleSignIn google = GoogleSignIn(
          scopes: const <String>['email', 'profile', 'openid'],
          clientId: kIsWeb && webClientId.isNotEmpty ? webClientId : null,
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
        );
        final account = await google.signIn();
        if (account == null) {
          throw ApiException('ยกเลิกการเข้าสู่ระบบ Google');
        }
        final auth = await account.authentication;
        final idToken = auth.idToken;
        final accessToken = auth.accessToken;
        if ((idToken == null || idToken.isEmpty) &&
            (accessToken == null || accessToken.isEmpty)) {
          throw ApiException(
            'ไม่ได้รับโทเค็นจาก Google — ตั้งค่า GOOGLE_WEB_CLIENT_ID (OAuth Web Client) ใน dart-define',
          );
        }
        return SocialAuthCredential(
          idToken: idToken,
          accessToken: accessToken,
        );
      case SocialProvider.facebook:
      case SocialProvider.line:
        throw ApiException(
          'ยังไม่ได้ตั้งค่า ${provider.label} — ใช้เบอร์โทรหรือ Google ก่อน',
        );
    }
  }
}
