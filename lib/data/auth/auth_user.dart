class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.merchantSlug,
    this.avatarUrl,
    this.avatarFrame,
  });

  final String id;
  final String phone;
  final String name;
  final String role;
  /// slug ร้านที่ผูกกับบัญชี (หลังอนุมัติ > ตรงกับ `RegisteredMerchant.slug` / ออเดอร์)
  final String? merchantSlug;
  final String? avatarUrl;
  final String? avatarFrame;

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    final slug = j['merchant_slug'] ?? j['merchantSlug'];
    final avatar = j['avatar_url'] ?? j['avatarUrl'];
    final frame = j['avatar_frame'] ?? j['avatarFrame'];
    return AuthUser(
      id: '${j['id'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      name: '${j['name'] ?? ''}',
      role: '${j['role'] ?? 'customer'}',
      merchantSlug: slug == null || '$slug'.isEmpty ? null : '$slug',
      avatarUrl: avatar == null || '$avatar'.isEmpty ? null : '$avatar',
      avatarFrame: frame == null || '$frame'.isEmpty ? null : '$frame',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        if (merchantSlug != null) 'merchant_slug': merchantSlug,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (avatarFrame != null) 'avatar_frame': avatarFrame,
      };
}
