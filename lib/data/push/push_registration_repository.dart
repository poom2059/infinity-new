import '../../config/app_config.dart';
import '../api/infinity_api_client.dart';

/// ลงทะเบียน device token — ต่อ Firebase FCM ได้ภายหลัง
class PushRegistrationRepository {
  PushRegistrationRepository(this._client);

  final InfinityApiClient _client;

  Future<void> registerDeviceToken(String token) async {
    if (!AppConfig.useApi) {
      return;
    }
    await _client.postJson('/v1/notifications/device', {'token': token});
  }
}
