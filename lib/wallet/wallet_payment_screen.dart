import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../config/app_config.dart';
import '../data/payments/payment_repository.dart';
import '../data/wallet/wallet_repository.dart';
import 'bank_app_options.dart';

/// วอเลต + เชื่อมแอปธนาคาร + เติมเงิน (โหมดสาธิตใช้ [PaymentRepository] + ยอดใน SharedPreferences)
class WalletPaymentScreen extends StatefulWidget {
  const WalletPaymentScreen({super.key});

  @override
  State<WalletPaymentScreen> createState() => _WalletPaymentScreenState();
}

class _WalletPaymentScreenState extends State<WalletPaymentScreen> {
  static const List<int> _quickAmounts = <int>[100, 200, 500, 1000];

  String? _linkedId;
  int _selectedQuick = 500;
  final TextEditingController _amountController = TextEditingController();
  bool _loadingLink = true;
  bool _submitting = false;
  WalletBalance? _balance;

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
    if (!mounted) {
      return;
    }
    final wallet = context.read<WalletRepository>();
    final bal = await wallet.balance();
    final link = await wallet.linkedBankAppId();
    if (!mounted) {
      return;
    }
    setState(() {
      _balance = bal;
      _linkedId = link;
      _loadingLink = false;
    });
  }

  int _parseAmountBaht() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    final v = int.tryParse(raw);
    if (v != null && v > 0) {
      return v;
    }
    return _selectedQuick;
  }

  Future<void> _selectBank(String id) async {
    final wallet = context.read<WalletRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loadingLink = true);
    await wallet.setLinkedBankAppId(id);
    await _reload();
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('เชื่อมแอป ${BankAppLinkOption.byId(id)?.appName ?? id} แล้ว (สาธิต)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _unlink() async {
    final wallet = context.read<WalletRepository>();
    setState(() => _loadingLink = true);
    await wallet.setLinkedBankAppId(null);
    await _reload();
  }

  Future<void> _topUp() async {
    final messenger = ScaffoldMessenger.of(context);
    final wallet = context.read<WalletRepository>();
    final pay = context.read<PaymentRepository>();
    final linked = await wallet.linkedBankAppId();
    if (!mounted) {
      return;
    }
    if (linked == null || linked.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกแอปธนาคารที่เชื่อมก่อน'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final amount = _parseAmountBaht();
    if (amount < 1) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ระบุจำนวนเงินให้ถูกต้อง'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final intent = await pay.createIntent(amountBaht: amount, orderId: 'topup-$amount');
      await pay.confirmMock(intent.id);
      await wallet.applyDemoTopUp(amount.toDouble());
      await _reload();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('ชำระ ฿$amount ผ่านแอปธนาคารสำเร็จ — ยอดวอเลตอัปเดตแล้ว'),
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
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = BankAppLinkOption.byId(_linkedId);
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
          const SizedBox(height: 22),
          const Text(
            'เชื่อมแอปธนาคาร',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            AppConfig.useApi
                ? 'โหมด API: การเชื่อมแอปธนาคารจะทำผ่านเซิร์ฟเวอร์เมื่อพร้อม'
                : 'เลือกธนาคารที่ต้องการใช้ตัดเงินจากบัญชีผ่านแอปธนาคารของคุณ แล้วเติมเข้าวอเลตหรือชำระค่าบริการในแอปนี้ (ขั้นตอนสาธิต ไม่เปิดแอปจริง)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (_loadingLink)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (linked != null)
            Material(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Icon(linked.iconData, color: AppColors.accent),
                ),
                title: Text(linked.nameTh, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                subtitle: Text(
                  'เชื่อมแล้ว: ${linked.appName}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: TextButton(
                  onPressed: AppConfig.useApi ? null : _unlink,
                  child: const Text('ยกเลิก'),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
              ),
              itemCount: kBankAppLinkOptions.length,
              itemBuilder: (context, i) {
                final b = kBankAppLinkOptions[i];
                return Material(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: AppConfig.useApi ? null : () => _selectBank(b.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(b.iconData, color: AppColors.textPrimary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  b.nameTh,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  b.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 26),
          const Text(
            'เติมเงินเข้าวอเลต',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'ระบบจะสร้างรายการชำระ (สาธิต) แล้วบวกยอดวอเลต — ใช้จ่ายค่าสั่งอาหารและบริการในแอปได้',
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
                onSelected: AppConfig.useApi
                    ? null
                    : (_) {
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
            enabled: !AppConfig.useApi,
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
            onPressed: (_submitting || AppConfig.useApi) ? null : _topUp,
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
                : const Text('ยืนยันชำระผ่านแอปธนาคารและเติมวอเลต', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
