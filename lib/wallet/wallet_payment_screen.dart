import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/payment_checkout_sheet.dart';
import '../data/wallet/wallet_repository.dart';

/// วอเลต + เติมเงินผ่าน PromptPay (Omise)
class WalletPaymentScreen extends StatefulWidget {
  const WalletPaymentScreen({super.key});

  @override
  State<WalletPaymentScreen> createState() => _WalletPaymentScreenState();
}

class _WalletPaymentScreenState extends State<WalletPaymentScreen> {
  static const List<int> _quickAmounts = <int>[100, 200, 500, 1000];

  int _selectedQuick = 500;
  final TextEditingController _amountController = TextEditingController();
  bool _submitting = false;
  WalletBalance? _balance;
  List<LedgerEntry> _ledger = const [];

  @override
  void initState() {
    super.initState();
    _amountController.text = '$_selectedQuick';
    _reload();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final wallet = context.read<WalletRepository>();
    final bal = await wallet.balance();
    final ledger = await wallet.ledger();
    if (!mounted) return;
    setState(() {
      _balance = bal;
      _ledger = ledger;
    });
  }

  int _parseAmountBaht() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    final v = int.tryParse(raw);
    if (v != null && v > 0) return v;
    return _selectedQuick;
  }

  Future<void> _topUp() async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = _parseAmountBaht();
    if (amount < 1) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ระบุจำนวนเงินให้ถูกต้อง'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final paid = await showPaymentCheckout(
        context,
        amountBaht: amount,
        purpose: 'wallet_topup',
        orderId: 'topup-$amount',
      );
      if (!mounted) return;
      if (paid == null || !paid.isSucceeded) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ยังไม่ได้ชำระเงิน'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      await _reload();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('เติมเงิน ฿$amount สำเร็จ'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('ไม่สำเร็จ: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('วอเลตและชำระเงิน'),
        backgroundColor: AppColors.topBar,
        foregroundColor: AppColors.topBarFg,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ยอดในแอป',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _balance != null ? '฿ ${_balance!.balanceBaht.toStringAsFixed(2)}' : '—',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _balance != null ? 'คะแนน ${_balance!.points}' : '—',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'เติมเงินเข้าวอเลต',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'ชำระด้วย PromptPay แล้วระบบจะเพิ่มยอดวอเลตอัตโนมัติหลังยืนยันการชำระ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((a) {
              final sel = _selectedQuick == a;
              return ChoiceChip(
                label: Text('฿$a'),
                selected: sel,
                onSelected: (_) {
                  setState(() {
                    _selectedQuick = a;
                    _amountController.text = '$a';
                  });
                },
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(color: sel ? AppColors.accent : AppColors.border),
                backgroundColor: AppColors.surfaceElevated,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'จำนวนเงิน (บาท)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _topUp,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ชำระด้วย PromptPay และเติมวอเลต', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          if (_ledger.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              'รายการล่าสุด',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 10),
            for (final e in _ledger.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text(e.createdAt, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: Text(
                  '${e.amountBaht >= 0 ? '+' : ''}฿${e.amountBaht.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: e.amountBaht >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
