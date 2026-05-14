class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.merchantSlug,
  });

  final String id;
  final String phone;
  final String name;
  final String role;
  /// slug ร้านที่ผูกกับบัญชี (หลังอนุมัติ > ตรงกับ `RegisteredMerchant.slug` / ออเดอร์)
  final String? merchantSlug;

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    final slug = j['merchant_slug'] ?? j['merchantSlug'];
    return AuthUser(
      id: '${j['id'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      name: '${j['name'] ?? ''}',
      role: '${j['role'] ?? 'customer'}',
      merchantSlug: slug == null || '$slug'.isEmpty ? null : '$slug',
    );
  }
}
