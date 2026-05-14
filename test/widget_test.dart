// Basic widget tests — สะท้อน UI ปัจจุบัน

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:infinity_new/main.dart' show InfinityProductionBootstrap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('splash scrollable then home shows Mart and nearby', (WidgetTester tester) async {
    await tester.pumpWidget(const InfinityProductionBootstrap());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('เปลี่ยนทุกที่ให้เป็นเงิน'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ร้านใกล้คุณ'), findsOneWidget);
    expect(find.text('หน้าแรก'), findsOneWidget);
    expect(find.text('Mart'), findsOneWidget);

    await tester.tap(find.text('Runner'));
    await tester.pumpAndSettle();
    expect(find.text('จองเดินทางและส่งของ'), findsOneWidget);
    expect(find.text('คุณจะไปที่ไหน?'), findsOneWidget);

    await tester.tap(find.text('บัญชี'));
    await tester.pumpAndSettle();
    expect(find.text('สมาชิก Infinity'), findsOneWidget);
    expect(find.text('การชำระเงิน'), findsOneWidget);
  });
}
