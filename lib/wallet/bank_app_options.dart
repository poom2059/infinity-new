import 'package:flutter/material.dart';

/// ตัวเลือกแอปธนาคารสำหรับเชื่อมตัดเงิน / เติมวอเลต (สาธิต — การเชื่อมจริงต้องใช้ SDK / Deep link ของแต่ละธนาคาร)
class BankAppLinkOption {
  const BankAppLinkOption({
    required this.id,
    required this.nameTh,
    required this.appName,
    required this.iconData,
  });

  final String id;
  final String nameTh;
  final String appName;
  final IconData iconData;

  static BankAppLinkOption? byId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final o in kBankAppLinkOptions) {
      if (o.id == id) {
        return o;
      }
    }
    return null;
  }
}

const List<BankAppLinkOption> kBankAppLinkOptions = <BankAppLinkOption>[
  BankAppLinkOption(
    id: 'kbank',
    nameTh: 'กสิกรไทย',
    appName: 'K PLUS',
    iconData: Icons.account_balance_rounded,
  ),
  BankAppLinkOption(
    id: 'scb',
    nameTh: 'ไทยพาณิชย์',
    appName: 'SCB EASY',
    iconData: Icons.account_balance_rounded,
  ),
  BankAppLinkOption(
    id: 'bbl',
    nameTh: 'กรุงเทพ',
    appName: 'Bualuang mBanking',
    iconData: Icons.account_balance_rounded,
  ),
  BankAppLinkOption(
    id: 'ktb',
    nameTh: 'กรุงไทย',
    appName: 'Krungthai NEXT',
    iconData: Icons.account_balance_rounded,
  ),
  BankAppLinkOption(
    id: 'ttb',
    nameTh: 'ทหารไทยธนชาต',
    appName: 'ttb touch',
    iconData: Icons.account_balance_rounded,
  ),
  BankAppLinkOption(
    id: 'bay',
    nameTh: 'กรุงศรีอยุธยา',
    appName: 'KMA',
    iconData: Icons.account_balance_rounded,
  ),
  BankAppLinkOption(
    id: 'gsb',
    nameTh: 'ออมสิน',
    appName: 'MyMo',
    iconData: Icons.savings_outlined,
  ),
  BankAppLinkOption(
    id: 'baac',
    nameTh: 'ธ.ก.ส.',
    appName: 'BAAC Mobile',
    iconData: Icons.agriculture_outlined,
  ),
];
