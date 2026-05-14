/// ขอบเขตผลิตภัณฑ์: บริการไรเดอร์/รถ/ส่งด่วนแบบเต็มระบบอยู่เฟสถัดไป
///
/// เฟส 1 (ปัจจุบัน): ฟู้ดเดลิเวอรี + Mart ในแอปลูกค้า + API ออเดอร์/ชำระเงินสาธิต
/// เฟส 2: แมตช์ไรเดอร์ แผนที่เรียลไทม์ SLA ค่าบริการแยกตามโซน
/// เฟส 3: แอปไรเดอร์ 3PL หรือฟลีตในองค์กร
abstract final class DeliveryProductScope {
  static const String phase1 = 'food_mart_core';
  static const String phase2 = 'rider_matching_maps';
  static const String phase3 = 'rider_app_3pl';
}
