// โมเดลฟู้ดเดลิเวอรีและเมนูออฟไลน์ — ใช้ร่วมกับ API / UI

class RegisteredMerchant {
  const RegisteredMerchant({
    required this.name,
    required this.category,
    required this.etaMinutes,
    required this.rating,
    required this.usageCount,
    required this.imageUrl,
    required this.distanceKm,
    required this.deliveryFee,
    this.slug = '',
  });

  final String name;
  final String category;
  final int etaMinutes;
  final double rating;
  final int usageCount;
  final String imageUrl;
  final double distanceKm;
  final int deliveryFee;
  /// คีย์ฝั่ง API; ถ้าว่างให้ใช้ชื่อร้านแทน
  final String slug;
}

const List<RegisteredMerchant> kSeedMerchants = <RegisteredMerchant>[
  RegisteredMerchant(
    slug: 'infinity-chicken',
    name: 'ไก่ทอดอินฟินิตี้',
    category: 'ไก่ทอด',
    etaMinutes: 15,
    rating: 4.8,
    usageCount: 1520,
    imageUrl: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=1200&q=80',
    distanceKm: 1.3,
    deliveryFee: 0,
  ),
  RegisteredMerchant(
    slug: 'daeng-noodle',
    name: 'แดงด่วนก๋วยเตี๋ยว',
    category: 'ก๋วยเตี๋ยว',
    etaMinutes: 20,
    rating: 4.7,
    usageCount: 1380,
    imageUrl: 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=1200&q=80',
    distanceKm: 2.4,
    deliveryFee: 15,
  ),
  RegisteredMerchant(
    slug: 'white-bowl-salad',
    name: 'สลัดโบว์ขาว',
    category: 'สุขภาพ',
    etaMinutes: 18,
    rating: 4.6,
    usageCount: 1240,
    imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=80',
    distanceKm: 3.2,
    deliveryFee: 20,
  ),
  RegisteredMerchant(
    slug: 'sushi-infinity',
    name: 'ซูชิอินฟินิตี้',
    category: 'ญี่ปุ่น',
    etaMinutes: 25,
    rating: 4.9,
    usageCount: 1190,
    imageUrl: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=1200&q=80',
    distanceKm: 4.9,
    deliveryFee: 35,
  ),
  RegisteredMerchant(
    slug: 'tum-saeb',
    name: 'ตำแซ่บโคตรนัว',
    category: 'อีสาน',
    etaMinutes: 22,
    rating: 4.5,
    usageCount: 980,
    imageUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=80',
    distanceKm: 2.7,
    deliveryFee: 20,
  ),
  RegisteredMerchant(
    slug: 'burger-lab',
    name: 'เบอร์เกอร์แล็บ',
    category: 'เบอร์เกอร์',
    etaMinutes: 19,
    rating: 4.6,
    usageCount: 870,
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=80',
    distanceKm: 5.5,
    deliveryFee: 45,
  ),
];

int mockMinOrderBaht(RegisteredMerchant m) =>
    (120 + (m.distanceKm * 15).round()).clamp(99, 299);

List<String> mockMerchantTags(RegisteredMerchant m) {
  return <String>[
    m.category,
    if (m.rating >= 4.7) 'แนะนำ',
    if (m.deliveryFee == 0) 'ส่งฟรี',
  ];
}

class DeliveryPhaseBreakdown {
  const DeliveryPhaseBreakdown({
    required this.phase1Title,
    required this.phase1Subtitle,
    required this.phase1Minutes,
    required this.phase2Title,
    required this.phase2Subtitle,
    required this.phase2Minutes,
    required this.phase3Title,
    required this.phase3Subtitle,
    required this.phase3Minutes,
    required this.distanceKm,
  });

  final String phase1Title;
  final String phase1Subtitle;
  final int phase1Minutes;
  final String phase2Title;
  final String phase2Subtitle;
  final int phase2Minutes;
  final String phase3Title;
  final String phase3Subtitle;
  final int phase3Minutes;
  final double distanceKm;

  int get totalMinutes => phase1Minutes + phase2Minutes + phase3Minutes;
}

DeliveryPhaseBreakdown estimateDeliveryPhases(
  RegisteredMerchant merchant, {
  required bool pickupMode,
}) {
  final d = merchant.distanceKm;
  if (pickupMode) {
    final p1 = (d / 20 * 60 + 3).round().clamp(6, 28);
    final p2 = (merchant.etaMinutes * 0.68).round().clamp(10, 40);
    return DeliveryPhaseBreakdown(
      phase1Title: 'เดินทางไปยังร้าน',
      phase1Subtitle: 'เฟส 1 · อิงระยะ ~${d.toStringAsFixed(1)} กม.',
      phase1Minutes: p1,
      phase2Title: 'ร้านทำอาหาร',
      phase2Subtitle: 'เฟส 2 · เวลาครัวจาก ETA ร้าน',
      phase2Minutes: p2,
      phase3Title: 'รับที่ร้าน',
      phase3Subtitle: 'เฟส 3 · ไม่มีขานำส่งถึงที่',
      phase3Minutes: 0,
      distanceKm: d,
    );
  }
  final p1 = (d / 24 * 60 + 3).round().clamp(5, 22);
  final p3 = (d / 17 * 60 + 4).round().clamp(8, 36);
  var p2 = merchant.etaMinutes - p1 - p3 + 3;
  if (p2 < 10) {
    p2 = 10;
  }
  p2 = p2.clamp(10, 45);
  return DeliveryPhaseBreakdown(
    phase1Title: 'ไรเดอร์ไปถึงร้าน',
    phase1Subtitle: 'เฟส 1 · จากระยะร้าน–คุณ ~${d.toStringAsFixed(1)} กม.',
    phase1Minutes: p1,
    phase2Title: 'ร้านทำอาหารจนเสร็จ',
    phase2Subtitle: 'เฟส 2 · ปรับให้สอดคล้อง ETA ${merchant.etaMinutes} น. ของร้าน',
    phase2Minutes: p2,
    phase3Title: 'ไรเดอร์ส่งถึงคุณ',
    phase3Subtitle: 'เฟส 3 · จากร้านถึงคุณ ~${d.toStringAsFixed(1)} กม.',
    phase3Minutes: p3,
    distanceKm: d,
  );
}

String phase3TimeLabel(DeliveryPhaseBreakdown b) =>
    b.phase3Minutes <= 0 ? '—' : '${b.phase3Minutes} น.';

class FoodMenuItem {
  const FoodMenuItem({
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    this.section = '',
  });

  final String name;
  final int price;
  final String description;
  final String imageUrl;
  /// หมวดเมนูในร้าน (เช่น อาหารและเครื่องดื่ม, ของหวาน) — ว่าง = ไม่แยกหมวดใน UI
  final String section;
}

List<FoodMenuItem> menuForMerchant(RegisteredMerchant merchant) {
  final defaultItems = <FoodMenuItem>[
    const FoodMenuItem(
      name: 'เมนูซิกเนเจอร์',
      price: 85,
      description: 'เมนูยอดนิยมของร้าน รสชาติจัดเต็ม',
      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80',
    ),
    const FoodMenuItem(
      name: 'เมนูแนะนำ',
      price: 79,
      description: 'ทำสดใหม่ทุกจาน พร้อมเสิร์ฟทันที',
      imageUrl: 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=1200&q=80',
    ),
    const FoodMenuItem(
      name: 'เซตสุดคุ้ม',
      price: 129,
      description: 'อิ่มคุ้มทั้งเซตสำหรับมื้อหลัก',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=80',
    ),
  ];

  switch (merchant.category) {
    case 'ไก่ทอด':
      return const [
        FoodMenuItem(
          name: 'ไก่ทอดซอสเกาหลี',
          price: 85,
          description: 'สะโพกไก่ทอดกรอบ คลุกซอสเกาหลีเข้มข้น',
          imageUrl: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=1200&q=80',
        ),
        FoodMenuItem(
          name: 'ไก่เผ็ดดับเบิลชีส',
          price: 95,
          description: 'ไก่ทอดรสเผ็ด เสิร์ฟพร้อมชีสเยิ้ม',
          imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=1200&q=80',
        ),
        FoodMenuItem(
          name: 'ชุดไก่ทอด 2 ชิ้น',
          price: 120,
          description: 'ไก่ทอด 2 ชิ้น + เฟรนช์ฟรายส์',
          imageUrl: 'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=1200&q=80',
        ),
      ];
    case 'ญี่ปุ่น':
      return const [
        FoodMenuItem(
          name: 'ข้าวหน้าปลาแซลมอน',
          price: 165,
          description: 'ปลาแซลมอนสดเสิร์ฟบนข้าวญี่ปุ่น',
          imageUrl: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=1200&q=80',
        ),
        FoodMenuItem(
          name: 'ซูชิรวมพรีเมียม',
          price: 189,
          description: 'ซูชิรวม 8 คำ วัตถุดิบคัดพิเศษ',
          imageUrl: 'https://images.unsplash.com/photo-1611143669185-af224c5e3252?w=1200&q=80',
        ),
        FoodMenuItem(
          name: 'ราเมนทงคตสึ',
          price: 149,
          description: 'ซุปราเมนกระดูกหมูเข้มข้น',
          imageUrl: 'https://images.unsplash.com/photo-1557872943-16a5ac26437e?w=1200&q=80',
        ),
      ];
    case 'เบอร์เกอร์':
      return const [
        FoodMenuItem(
          name: 'ชีสเบอร์เกอร์เนื้อย่าง',
          price: 99,
          description: 'เนื้อย่างฉ่ำ ซอสสูตรพิเศษ ชีสเต็มคำ',
          imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=80',
        ),
        FoodMenuItem(
          name: 'เบอร์เกอร์ไก่กรอบ',
          price: 89,
          description: 'ไก่กรอบชิ้นใหญ่ ผักสดซอสกลมกล่อม',
          imageUrl: 'https://images.unsplash.com/photo-1520072959219-c595dc870360?w=1200&q=80',
        ),
        FoodMenuItem(
          name: 'ดับเบิลมีทคอมโบ',
          price: 159,
          description: 'ดับเบิลแพตตี้ เสิร์ฟพร้อมเฟรนช์ฟรายส์',
          imageUrl: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=1200&q=80',
        ),
      ];
    default:
      return defaultItems;
  }
}

class OrderLine {
  const OrderLine({
    required this.itemName,
    required this.unitPrice,
    required this.qty,
  });

  final String itemName;
  final int unitPrice;
  final int qty;
}

class PlacedOrder {
  PlacedOrder({
    required this.id,
    required this.placedAt,
    required this.merchant,
    required this.lines,
    required this.totalBaht,
    required this.deliveryBreakdown,
    required this.pickupMode,
    this.statusLabel = 'กำลังจัดส่ง',
  });

  final String id;
  final DateTime placedAt;
  final RegisteredMerchant merchant;
  final List<OrderLine> lines;
  final int totalBaht;
  final DeliveryPhaseBreakdown deliveryBreakdown;
  final bool pickupMode;
  String statusLabel;

  bool get isActive {
    const done = {'สำเร็จ', 'ส่งสำเร็จ', 'ยกเลิก'};
    return !done.contains(statusLabel);
  }
}

RegisteredMerchant? findMerchantByName(String name) {
  for (final m in kSeedMerchants) {
    if (m.name == name) {
      return m;
    }
  }
  return null;
}
