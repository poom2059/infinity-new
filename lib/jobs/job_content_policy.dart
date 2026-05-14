/// กรองเนื้อหาต้องห้าม (ขายบริการ / 18+) แบบง่ายสำหรับโหมดสาธิต
bool jobTextViolatesPolicy(String text) {
  final String s = text.toLowerCase();
  const forbidden = <String>[
    '18+',
    'โป๊',
    'ลามก',
    'xxx',
    'porn',
    'sex',
    'escort',
    'ทางเพศ',
    'บริการทางเพศ',
    'ขายบริการ',
    'นวดโป๊',
    'คอลเซนเตอร์',
    'onlyfans',
    'only fans',
  ];
  for (final String w in forbidden) {
    if (s.contains(w)) {
      return true;
    }
  }
  return false;
}
