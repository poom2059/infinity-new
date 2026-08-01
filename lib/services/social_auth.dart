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
        final GoogleSignIn google = GoogleSignIn(
          scopes: const <String>['email', 'profile'],
          serverClientId: AppConfig.googleServerClientId.isEmpty
              ? null
              : AppConfig.googleServerClientId,
        );
        final account = await google.signIn();
        if (account == null) {
          throw ApiException('ยกเลิกการเข้าสู่ระบบ Google');
        }
        final auth = await account.authentication;
        if ((auth.idToken == null || auth.idToken!.isEmpty) &&
            (auth.accessToken == null || auth.accessToken!.isEmpty)) {
          throw ApiException('ไม่ได้รับโทเค็นจาก Google');
        }
        return SocialAuthCredential(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        );
      case SocialProvider.facebook:
      case SocialProvider.line:
        throw ApiException(
          'กรุณาตั้งค่า ${provider.label} OAuth บนเซิร์ฟเวอร์แล้วใช้ SDK ของผู้ให้บริการในแอป',
        );
    }
  }
}
