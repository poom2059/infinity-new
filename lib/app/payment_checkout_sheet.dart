import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/payments/payment_repository.dart';
import 'app_theme.dart';

/// แสดง QR PromptPay / รอชำระเงินจนสำเร็จ
Future<PaymentIntent?> showPaymentCheckout(
  BuildContext context, {
  required int amountBaht,
  String purpose = 'order',
  String? orderId,
}) async {
  final pay = context.read<PaymentRepository>();
  final intent = await pay.createIntent(
    amountBaht: amountBaht,
    purpose: purpose,
    orderId: orderId,
  );
  if (!context.mounted) return null;
  return completePaymentCheckout(context, intent);
}

/// รอชำระ intent ที่มีอยู่แล้ว (เช่น มัดจำงาน)
Future<PaymentIntent?> completePaymentCheckout(BuildContext context, PaymentIntent intent) async {
  final pay = context.read<PaymentRepository>();
  if (intent.isSucceeded) return intent;

  if (intent.simulate) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการชำระ (จำลอง)'),
        content: Text('ยอด ฿${intent.amountBaht} — โหมดจำลองเปิดอยู่บนเซิร์ฟเวอร์'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยันชำระ')),
        ],
      ),
    );
    if (ok != true) return null;
    await pay.confirmSimulate(intent.id);
    return pay.fetchIntent(intent.id);
  }

  return showDialog<PaymentIntent>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PaymentWaitDialog(intent: intent, pay: pay),
  );
}

class _PaymentWaitDialog extends StatefulWidget {
  const _PaymentWaitDialog({required this.intent, required this.pay});
  final PaymentIntent intent;
  final PaymentRepository pay;

  @override
  State<_PaymentWaitDialog> createState() => _PaymentWaitDialogState();
}

class _PaymentWaitDialogState extends State<_PaymentWaitDialog> {
  late PaymentIntent _intent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _intent = widget.intent;
    _poll();
  }

  Future<void> _poll() async {
    try {
      final result = await widget.pay.waitUntilPaid(_intent.id);
      if (!mounted) return;
      if (result.isSucceeded) {
        Navigator.pop(context, result);
      } else if (result.isFailed) {
        setState(() => _error = 'การชำระเงินไม่สำเร็จ');
      } else {
        setState(() => _error = 'หมดเวลารอชำระเงิน');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('ชำระเงินด้วย PromptPay', style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ยอด ฿${_intent.amountBaht}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (_intent.qrImageUrl != null && _intent.qrImageUrl!.isNotEmpty)
            Image.network(_intent.qrImageUrl!, width: 220, height: 220, fit: BoxFit.contain)
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'สแกน QR แล้วรอระบบยืนยันอัตโนมัติ…',
            textAlign: TextAlign.center,
            style: TextStyle(color: _error != null ? Colors.redAccent : AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}
