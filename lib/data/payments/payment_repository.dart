import '../../config/app_config.dart';
import '../api/infinity_api_client.dart';

class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.status,
    required this.amountBaht,
  });

  final String id;
  final String status;
  final int amountBaht;

  factory PaymentIntent.fromJson(Map<String, dynamic> j) {
    return PaymentIntent(
      id: '${j['id']}',
      status: '${j['status']}',
      amountBaht: (j['amount_baht'] as num?)?.toInt() ?? 0,
    );
  }
}

/// จำลอง payment intent + webhook ฝั่งเซิร์ฟเวอร์ (แทน Omise/2C2P ระหว่างพัฒนา)
class PaymentRepository {
  PaymentRepository(this._client);

  final InfinityApiClient _client;

  Future<PaymentIntent> createIntent({required int amountBaht, String? orderId}) async {
    if (!AppConfig.useApi) {
      return PaymentIntent(
        id: 'local-intent-${DateTime.now().millisecondsSinceEpoch}',
        status: 'succeeded',
        amountBaht: amountBaht,
      );
    }
    final data = await _client.postJson('/v1/payments/intents', {
      'amount_baht': amountBaht,
      if (orderId != null) 'order_id': orderId,
    }) as Map<String, dynamic>;
    return PaymentIntent.fromJson(data);
  }

  Future<void> confirmMock(String intentId) async {
    if (!AppConfig.useApi) {
      return;
    }
    await _client.postJson('/v1/payments/$intentId/confirm-mock', {});
  }
}
