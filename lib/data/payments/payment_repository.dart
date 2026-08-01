import '../api/infinity_api_client.dart';

class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.status,
    required this.amountBaht,
    this.qrImageUrl,
    this.authorizeUri,
    this.simulate = false,
    this.purpose,
  });

  final String id;
  final String status;
  final int amountBaht;
  final String? qrImageUrl;
  final String? authorizeUri;
  final bool simulate;
  final String? purpose;

  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';

  factory PaymentIntent.fromJson(Map<String, dynamic> j) {
    return PaymentIntent(
      id: '${j['id']}',
      status: '${j['status']}',
      amountBaht: (j['amount_baht'] as num?)?.toInt() ?? 0,
      qrImageUrl: j['qr_image_url'] == null ? null : '${j['qr_image_url']}',
      authorizeUri: j['authorize_uri'] == null ? null : '${j['authorize_uri']}',
      simulate: j['simulate'] == true,
      purpose: j['purpose'] == null ? null : '${j['purpose']}',
    );
  }
}

class PaymentRepository {
  PaymentRepository(this._client);

  final InfinityApiClient _client;

  Future<PaymentIntent> createIntent({
    required int amountBaht,
    String? orderId,
    String purpose = 'order',
    String? returnUri,
  }) async {
    final data = await _client.postJson('/v1/payments/intents', {
      'amount_baht': amountBaht,
      'purpose': purpose,
      if (orderId != null) 'order_id': orderId,
      if (returnUri != null) 'return_uri': returnUri,
    }) as Map<String, dynamic>;
    return PaymentIntent.fromJson(data);
  }

  Future<PaymentIntent> fetchIntent(String intentId) async {
    final data = await _client.getJson('/v1/payments/$intentId') as Map<String, dynamic>;
    return PaymentIntent.fromJson(data);
  }

  Future<void> confirmSimulate(String intentId) async {
    await _client.postJson('/v1/payments/$intentId/confirm-simulate', {});
  }

  /// Poll until succeeded/failed or timeout.
  Future<PaymentIntent> waitUntilPaid(
    String intentId, {
    Duration timeout = const Duration(minutes: 3),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final intent = await fetchIntent(intentId);
      if (intent.isSucceeded || intent.isFailed) {
        return intent;
      }
      await Future<void>.delayed(interval);
    }
    return fetchIntent(intentId);
  }
}
