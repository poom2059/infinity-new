import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'app/app_scope.dart';
import 'app/app_theme.dart';
import 'app/avatar_frames.dart';
import 'app/login_screen.dart';
import 'app/notifications_screen.dart';
import 'app/payment_checkout_sheet.dart';
import 'app/profile_edit_screen.dart';
import 'app/saved_places_screen.dart';
import 'app/ui_strings_th.dart';
import 'config/app_config.dart';
import 'data/addresses/address_repository.dart';
import 'data/admin/admin_repository.dart';
import 'data/api/infinity_api_client.dart';
import 'data/auth/auth_repository.dart';
import 'data/auth/auth_session.dart';
import 'data/auth/auth_user.dart';
import 'data/bookings/booking_repository.dart';
import 'data/catalog/catalog_repository.dart';
import 'data/maps/maps_repository.dart';
import 'data/merchant/merchant_repository.dart';
import 'data/notifications/notification_store.dart';
import 'data/orders/order_repository.dart';
import 'data/payments/payment_repository.dart';
import 'data/places/saved_places_store.dart';
import 'data/profile/profile_store.dart';
import 'data/push/push_registration_repository.dart';
import 'data/wallet/wallet_repository.dart';
import 'domain/food_ordering.dart';
import 'firebase_options.dart';
import 'jobs/job_hub_tab.dart';
import 'jobs/job_store.dart';
import 'portals/admin_portal_screen.dart';
import 'portals/merchant_menu_manage_screen.dart';
import 'portals/merchant_onboarding_screen.dart';
import 'portals/merchant_portal_screen.dart';
import 'services/web_redirect.dart';
import 'wallet/wallet_payment_screen.dart';

/// โลโก้หน้า splash (กว้าง)
const double kLogoSplashWidth = 504;
/// โลโก้ในแถบหัวทุกหน้า (เดิม 38 เพิ่ม 50%)
const double kLogoAppBarHeight = 57;

const Color kUnifiedTopBarBg = AppColors.topBar;
const Color kUnifiedTopBarFg = AppColors.topBarFg;

/// ความสูงแถบหัวให้รองรับโลโก้ใหญ่ขึ้น
const double kUnifiedTopBarToolbarHeight = 62;

/// แผ่นข้อมูลสาธิต — ช่องไฟและสีชัด
void showDemoInfoSheet(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  List<String>? bullets,
  String primaryLabel = 'รับทราบ',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) {
      final double bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 16, 22, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                for (final String p in paragraphs) ...[
                  Text(
                    p,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (bullets != null && bullets.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final String b in bullets) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                if (secondaryLabel != null && onSecondary != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        onSecondary();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(secondaryLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      onPrimary?.call();
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE3001B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// ฮับค้นหา — เลือกไปสั่งอาหารหรือ Mart
void showAppSearchSheet(
  BuildContext context, {
  required VoidCallback onPickFood,
  required VoidCallback onPickMart,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) {
      final double bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ค้นหาในแอป',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'เลือกบริการที่ต้องการ แล้วค้นหาร้านอาหารหรือสินค้าใน${UiStringsTh.mart}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Icon(Icons.restaurant_rounded, color: Color(0xFFE3001B)),
                ),
                title: const Text(
                  'สั่งอาหาร',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'เปิดรายการร้านและเมนู',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  onPickFood();
                },
              ),
              Divider(height: 28, color: AppColors.border.withValues(alpha: 0.6)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1A2E1C),
                  child: Icon(Icons.shopping_basket_rounded, color: Colors.green.shade300),
                ),
                title: const Text(
                  UiStringsTh.mart,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'ของใช้และของสดครบในที่เดียว',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  onPickMart();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// ปุ่มกระดิ่งแจ้งเตือน พร้อมป้ายจำนวนที่ยังไม่อ่าน
class _NotifyBellButton extends StatelessWidget {
  const _NotifyBellButton({required this.onPressed, required this.color});

  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final int unread = context.watch<NotificationStore>().unreadCount;
    return IconButton(
      onPressed: onPressed,
      tooltip: 'แจ้งเตือน',
      color: color,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3001B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kUnifiedTopBarBg, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppBarLogo extends StatelessWidget {
  const _AppBarLogo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/infinity_logo.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (context, _, _) => Text(
        UiStringsTh.appName,
        style: TextStyle(
          fontSize: height * 0.52,
          fontWeight: FontWeight.w900,
          color: kUnifiedTopBarFg,
        ),
      ),
    );
  }
}

class _AppBarTitleWithLogo extends StatelessWidget {
  const _AppBarTitleWithLogo({
    required this.title,
    this.titleStyle,
  });

  final String title;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _AppBarLogo(height: kLogoAppBarHeight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle ??
                const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: kUnifiedTopBarFg,
                ),
          ),
        ),
      ],
    );
  }
}

/// โทเคน/ข้อผิดพลาดที่ได้จาก OAuth redirect บนเว็บ (อ่านครั้งเดียวตอนเปิดแอป)
String? _oauthToken;
String? _oauthError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _oauthToken = WebRedirect.takeAuthToken();
  _oauthError = WebRedirect.takeAuthError();
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const InfinityProductionBootstrap());
}

class OrderStore {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final List<PlacedOrder> _orders = <PlacedOrder>[];
  static bool _remoteLoadAttempted = false;

  static List<PlacedOrder> ordersForDisplay() {
    final list = List<PlacedOrder>.from(_orders);
    list.sort((PlacedOrder a, PlacedOrder b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }
      return b.placedAt.compareTo(a.placedAt);
    });
    return list;
  }

  static Future<String> addOrder(PlacedOrder order) async {
    if (AppScope.ordersRemote) {
      try {
        final saved = await AppScope.orderRepository!.createOrder(order, AppScope.merchantsForOrders);
        _orders.insert(0, saved);
        revision.value++;
        return saved.id;
      } catch (_) {
        // ตกไปบันทึกในเครื่อง
      }
    }
    _orders.insert(0, order);
    revision.value++;
    return order.id;
  }

  static Future<void> markCompleted(String orderId) async {
    if (AppScope.ordersRemote) {
      try {
        await AppScope.orderRepository!.markComplete(orderId);
      } catch (_) {}
    }
    for (final PlacedOrder o in _orders) {
      if (o.id == orderId) {
        const done = {'สำเร็จ', 'ส่งสำเร็จ', 'ยกเลิก'};
        if (!done.contains(o.statusLabel)) {
          o.statusLabel = 'สำเร็จ';
          revision.value++;
        }
        break;
      }
    }
  }

  static Future<void> loadRemoteHistory() async {
    if (!AppScope.ordersRemote || _remoteLoadAttempted) {
      return;
    }
    _remoteLoadAttempted = true;
    try {
      final remote = await AppScope.orderRepository!.listOrders(AppScope.merchantsForOrders);
      _orders.clear();
      _orders.addAll(remote);
      revision.value++;
    } catch (_) {}
  }
}

class InfinityApp extends StatelessWidget {
  const InfinityApp({super.key, this.home});

  /// ถ้า null ใช้ [SplashScreen] (โฟลว์ออฟไลน์)
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: UiStringsTh.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.mainDark(),
      home: home ?? const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SplashTheme.overlay(),
      child: Scaffold(
        backgroundColor: SplashTheme.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/infinity_logo.png',
                    width: kLogoSplashWidth,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'เปลี่ยนทุกที่ให้เป็นเงิน',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: SplashTheme.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 36),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'กรุณาเข้าสู่ระบบด้วยเบอร์โทรหรือบัญชีโซเชียล',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _walletBalanceTick = 0;
  List<RegisteredMerchant> _catalogMerchants = <RegisteredMerchant>[];
  AuthUser? _accountUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncCatalog();
      _loadAccountUser();
    });
  }

  Future<void> _syncCatalog() async {
    try {
      final repo = context.read<CatalogRepository>();
      final list = await repo.fetchMerchants();
      if (!mounted) {
        return;
      }
      setState(() {
        _catalogMerchants = list;
        AppScope.merchantsForOrders = list;
      });
    } catch (_) {}
  }

  Future<void> _loadAccountUser() async {
    if (!AppConfig.useApi) {
      return;
    }
    try {
      final u = await context.read<AuthRepository>().fetchMe();
      if (mounted) {
        setState(() => _accountUser = u);
      }
    } catch (_) {}
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE3001B),
      ),
    );
  }

  Future<void> _submitBooking(String kind, {Map<String, dynamic>? payload, String? title}) async {
    try {
      final booking = context.read<BookingRepository>();
      final created = await booking.create(kind: kind, payload: payload ?? {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${title ?? kind} บันทึกแล้ว (#${created['id']}) — รอเจ้าหน้าที่ติดต่อ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สำเร็จ: $e')),
      );
    }
  }

  void _onHomeTap(String code) {
    if (code.startsWith('demo:vehicle:')) {
      final String vehicle = code.substring('demo:vehicle:'.length);
      _submitBooking('ride', title: 'คำขอรถ$vehicle', payload: {'vehicle': vehicle});
      return;
    }
    switch (code) {
      case 'notify':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        );
        return;
      case 'search':
        showAppSearchSheet(
          context,
          onPickFood: _openFoodOrdering,
          onPickMart: _openMart,
        );
        return;
      case 'qr':
        _submitBooking('qr_pay', title: 'คำขอสแกน QR');
        return;
      case 'demo:express':
        _submitBooking('express', title: 'คำขอส่งด่วน');
        return;
      case 'demo:promo':
        showDemoInfoSheet(
          context,
          title: 'โปรโมชัน',
          paragraphs: const <String>[
            'รวมดีลส่งฟรี ส่วนลด และคูปองสำหรับร้านที่ร่วมรายการ',
            'แตะการ์ดโปรด้านล่างเพื่อดูรายละเอียดแต่ละแคมเปญ',
          ],
        );
        return;
      case 'demo:travel':
        _submitBooking('travel', title: 'คำขอเดินทาง');
        return;
      case 'demo:wallet':
        Navigator.of(context)
            .push<void>(
          MaterialPageRoute<void>(builder: (_) => const WalletPaymentScreen()),
        )
            .then((_) {
          if (mounted) {
            setState(() => _walletBalanceTick++);
          }
        });
        return;
      case 'demo:points':
        _submitBooking('points_redeem', title: 'คำขอแลกคะแนน');
        return;
      case 'demo:promos_all':
        showDemoInfoSheet(
          context,
          title: 'โปรทั้งหมด',
          paragraphs: const <String>[
            'รวมแคมเปญส่งฟรี ลดเปอร์เซ็นต์ และสิทธิ์สมาชิก',
            'เลื่อนดูการ์ดด้านล่างบนหน้าแรก หรือกลับมาที่เมนูนี้ภายหลัง',
          ],
        );
        return;
      case 'demo:promo_ship':
        showDemoInfoSheet(
          context,
          title: 'ส่งฟรี 3 กม.',
          paragraphs: const <String>[
            'เฉพาะร้านที่แสดงป้ายร่วมรายการ และระยะจัดส่งตามเงื่อนไขแคมเปญ',
            'ค่าส่งจะถูกหักก่อนชำระเงินเมื่อสั่งจากร้านที่เข้าเงื่อนไข',
          ],
        );
        return;
      case 'demo:promo_60':
        showDemoInfoSheet(
          context,
          title: 'ลดสูงสุด 60%',
          paragraphs: const <String>[
            'ดีลแฟลชตามช่วงเวลา — ส่วนลดขึ้นกับร้านและเมนูที่ร่วมรายการ',
            'กดเข้าร้านแล้วดูแท็กโปรบนเมนูก่อนเพิ่มลงตะกร้า',
          ],
        );
        return;
      case 'demo:promo_new':
        showDemoInfoSheet(
          context,
          title: 'สมาชิกใหม่',
          paragraphs: const <String>[
            'รับคูปองต้อนรับเมื่อลงทะเบียนครั้งแรก (เมื่อระบบบัญชีพร้อม)',
            'เงื่อนไขการใช้จะแสดงในรายละเอียดคูปอง',
          ],
        );
        return;
      case 'tab:food':
        _openFoodOrdering();
        return;
      case 'tab:mart':
        _openMart();
        return;
      case 'demo:car_ride':
        _submitBooking('ride', title: 'คำขอจองรถ', payload: {'vehicle': 'รถยนต์'});
        return;
      case 'demo:saved_places':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const SavedPlacesScreen()),
        );
        return;
      case 'demo:help_centre':
        showDemoInfoSheet(
          context,
          title: 'ศูนย์ช่วยเหลือ',
          paragraphs: const <String>[
            'คำถามที่พบบ่อย แชทกับฝ่ายดูแล และสถานะบริการ',
            'ช่องทางจริงจะเปิดเมื่อเชื่อมระบบซัพพอร์ต',
          ],
        );
        return;
      case 'demo:settings':
        showDemoInfoSheet(
          context,
          title: 'ตั้งค่า',
          paragraphs: const <String>[
            'ภาษา การแจ้งเตือน ความเป็นส่วนตัว และการเชื่อมต่อบัญชี',
            'เมนูนี้เป็นตัวอย่างการจัดวาง — ค่าจริงจะบันทึกเมื่อมีระบบบัญชี',
          ],
        );
        return;
      case 'demo:payment':
        Navigator.of(context)
            .push<void>(
          MaterialPageRoute<void>(builder: (_) => const WalletPaymentScreen()),
        )
            .then((_) {
          if (mounted) {
            setState(() => _walletBalanceTick++);
          }
        });
        return;
      case 'demo:profile':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ProfileEditScreen()),
        );
        return;
      case 'demo:about':
        showDemoInfoSheet(
          context,
          title: 'เกี่ยวกับ ${UiStringsTh.appName}',
          paragraphs: const <String>[
            'แอปสั่งอาหาร งาน และบริการขนส่ง — เชื่อมต่อ API จริง',
          ],
        );
        return;
      default:
        _showAction(code);
    }
  }

  void _previewNearbyShop(RegisteredMerchant shop) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${shop.category} · ส่งโดยประมาณ ${shop.etaMinutes} นาที · ระยะ ${shop.distanceKm} กม.\nค่าส่ง ฿${shop.deliveryFee} · เรตติ้ง ${shop.rating}',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ปิด', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) => RestaurantDetailScreen(
                                merchant: shop,
                                menuItems: AppConfig.useApi ? null : menuForMerchant(shop),
                                pickupMode: false,
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE3001B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('เข้าสู่ร้าน', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<RegisteredMerchant> _sortedRegisteredMerchants() {
    final merchants = List<RegisteredMerchant>.from(_catalogMerchants);
    merchants.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return merchants;
  }

  void _openFoodOrdering() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MerchantListScreen(
          merchants: _sortedRegisteredMerchants(),
        ),
      ),
    );
  }

  void _openMart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const MartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 900;
    final bool isHome = _currentIndex == 0;
    final Widget content = isHome
        ? _HomeTab(
            merchants: _sortedRegisteredMerchants(),
            onHomeTap: _onHomeTap,
            onOpenFoodOrdering: _openFoodOrdering,
            onOpenMart: _openMart,
            onPreviewShop: _previewNearbyShop,
            walletBalanceKey: _walletBalanceTick,
          )
        : _currentIndex == 1
            ? ValueListenableBuilder<int>(
                valueListenable: OrderStore.revision,
                builder: (BuildContext context, _, _) {
                  OrderStore.loadRemoteHistory();
                  return _OrdersTabView(merchants: _sortedRegisteredMerchants());
                },
              )
            : _currentIndex == 2
                ? _GrabDeliveryTab(onHomeTap: _onHomeTap)
                : _currentIndex == 3
                    ? JobHubTab(accountUser: _accountUser)
                    : _GrabAccountTab(
                    onHomeTap: _onHomeTap,
                    onOpenOrders: () => setState(() => _currentIndex = 1),
                    accountUser: _accountUser,
                    walletBalanceKey: _walletBalanceTick,
                    onOpenAdmin: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (context) => const AdminPortalScreen()),
                      );
                    },
                    onOpenMerchantPortal: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (context) => const MerchantPortalScreen()),
                      );
                    },
                    onOpenMerchantHub: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) => MerchantOnboardingScreen(
                            catalogMerchants: _sortedRegisteredMerchants(),
                            onOpenRestaurantDetail: (BuildContext navCtx, RegisteredMerchant merchant) {
                              Navigator.of(navCtx).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) => RestaurantDetailScreen(
                                    merchant: merchant,
                                    menuItems: AppConfig.useApi ? null : menuForMerchant(merchant),
                                    pickupMode: false,
                                  ),
                                ),
                              );
                            },
                            onAccountChanged: () {
                              _loadAccountUser();
                              _syncCatalog();
                            },
                          ),
                        ),
                      );
                    },
                    onOpenMerchantMenu: AppConfig.useApi
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext ctx) => MerchantMenuManageScreen(
                                  onPreviewCustomerView: (BuildContext navCtx, RegisteredMerchant merchant) {
                                    Navigator.of(navCtx).push(
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) => RestaurantDetailScreen(
                                          merchant: merchant,
                                          menuItems: AppConfig.useApi ? null : menuForMerchant(merchant),
                                          pickupMode: false,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        : null,
                  );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: isHome
          ? null
          : AppBar(
              backgroundColor: kUnifiedTopBarBg,
              foregroundColor: kUnifiedTopBarFg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: kUnifiedTopBarToolbarHeight,
              centerTitle: false,
              title: _AppBarLogo(height: kLogoAppBarHeight),
              actions: [
                _NotifyBellButton(
                  onPressed: () => _onHomeTap('notify'),
                  color: kUnifiedTopBarFg,
                ),
              ],
            ),
      body: SafeArea(
        top: !isHome,
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1080 : 640,
                  maxHeight: constraints.maxHeight,
                  minHeight: constraints.maxHeight,
                ),
                child: content,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'หน้าแรก'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'ออเดอร์'),
          BottomNavigationBarItem(icon: Icon(Icons.delivery_dining_outlined), label: 'Runner'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), label: 'Job'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'บัญชี'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.merchants,
    required this.onHomeTap,
    required this.onOpenFoodOrdering,
    required this.onOpenMart,
    required this.onPreviewShop,
    required this.walletBalanceKey,
  });

  static const Color _brandRed = Color(0xFFE3001B);
  static const Color _iconCircleBg = Color(0xFFFFE8EA);

  final List<RegisteredMerchant> merchants;
  final ValueChanged<String> onHomeTap;
  final VoidCallback onOpenFoodOrdering;
  final VoidCallback onOpenMart;
  final ValueChanged<RegisteredMerchant> onPreviewShop;
  final int walletBalanceKey;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.canvas,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              color: kUnifiedTopBarBg,
              padding: EdgeInsets.fromLTRB(12, topPad, 12, 28),
              child: SizedBox(
                height: kUnifiedTopBarToolbarHeight,
                child: Row(
                  children: [
                    const _AppBarLogo(height: kLogoAppBarHeight),
                    const Spacer(),
                    _NotifyBellButton(
                      onPressed: () => onHomeTap('notify'),
                      color: kUnifiedTopBarFg,
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GrabSearchPill(onHomeTap: onHomeTap),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _GrabServiceRow(
                onHomeTap: onHomeTap,
                onOpenFoodOrdering: onOpenFoodOrdering,
                onOpenMart: onOpenMart,
                iconCircleBg: _iconCircleBg,
                accentRed: _brandRed,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BalancePointsRow(onHomeTap: onHomeTap, refreshKey: walletBalanceKey),
            ),
            const SizedBox(height: 20),
            _GrabPromoSection(onHomeTap: onHomeTap),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _NearbyShopsSectionLight(merchants: merchants, onPreviewShop: onPreviewShop),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// แท็บ «Runner» — โครงสร้างคล้ายซูเปอร์แอป (ช่องปลายทาง ชิปที่อยู่ กริดบริการ โปร)
class _GrabDeliveryTab extends StatelessWidget {
  const _GrabDeliveryTab({required this.onHomeTap});

  final ValueChanged<String> onHomeTap;

  static const Color _brandRed = Color(0xFFE3001B);
  static const Color _iconCircleBg = Color(0xFFFFE8EA);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'จองเดินทางและส่งของ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ระบุจุดรับ–ส่ง เลือกบริการ และเห็นค่าโดยประมาณก่อนยืนยัน (ข้อมูลสาธิต)',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Material(
                color: AppColors.surface,
                elevation: 1,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onHomeTap('search'),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, color: _brandRed, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'คุณจะไปที่ไหน?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'แตะเพื่อค้นหาที่อยู่หรือเลือกบริการ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Text(
                      'ที่อยู่ยอดนิยม',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => onHomeTap('demo:saved_places'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFE3001B)),
                      child: const Text('จัดการ', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _GrabPlaceChip(label: 'บ้าน', onTap: () => onHomeTap('demo:saved_places')),
                    _GrabPlaceChip(label: 'ที่ทำงาน', onTap: () => onHomeTap('demo:saved_places')),
                    _GrabPlaceChip(label: '+ เพิ่ม', onTap: () => onHomeTap('demo:saved_places')),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'เพิ่มรถ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 4,
                childAspectRatio: 0.72,
                children: [
                  _GrabServiceChip(
                    icon: Icons.pedal_bike_rounded,
                    label: 'จักรยาน',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:จักรยาน'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.two_wheeler_rounded,
                    label: 'มอเตอร์ไซต์',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:มอเตอร์ไซต์'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.directions_car_filled_rounded,
                    label: 'รถยนต์',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:รถยนต์'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.electric_rickshaw_outlined,
                    label: 'รถตุ๊กตุ๊ก',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:รถตุ๊กตุ๊ก'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.airport_shuttle_rounded,
                    label: 'รถซูโบลุ',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:รถซูโบลุ'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.local_shipping_rounded,
                    label: 'รถสิบล้อ',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:รถสิบล้อ'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.fire_truck_outlined,
                    label: 'รถกะบะ',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    labelMaxLines: 2,
                    onTap: () => onHomeTap('demo:vehicle:รถกะบะ'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'บริการ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 4,
                childAspectRatio: 0.82,
                children: [
                  _GrabServiceChip(
                    icon: Icons.local_shipping_rounded,
                    label: 'ส่งด่วน',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    onTap: () => onHomeTap('demo:express'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.restaurant_rounded,
                    label: 'อาหาร',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    onTap: () => onHomeTap('tab:food'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.shopping_basket_rounded,
                    label: UiStringsTh.mart,
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    onTap: () => onHomeTap('tab:mart'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.percent_rounded,
                    label: 'โปร',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    onTap: () => onHomeTap('demo:promo'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.map_outlined,
                    label: 'แผนที่',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    onTap: () => onHomeTap('demo:travel'),
                  ),
                  _GrabServiceChip(
                    icon: Icons.headset_mic_outlined,
                    label: 'ช่วยเหลือ',
                    iconBg: _iconCircleBg,
                    iconColor: _brandRed,
                    onTap: () => onHomeTap('demo:help_centre'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _GrabPromoSection(onHomeTap: onHomeTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrabPlaceChip extends StatelessWidget {
  const _GrabPlaceChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
        ),
        onPressed: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

/// แท็บ «บัญชี» — หัวโปรไฟล์ ยอด/คะแนน รายการเมนูแบบรายการเดียว
class _GrabAccountTab extends StatelessWidget {
  const _GrabAccountTab({
    required this.onHomeTap,
    required this.onOpenOrders,
    this.accountUser,
    required this.onOpenAdmin,
    required this.onOpenMerchantPortal,
    required this.onOpenMerchantHub,
    required this.walletBalanceKey,
    this.onOpenMerchantMenu,
  });

  final ValueChanged<String> onHomeTap;
  final VoidCallback onOpenOrders;
  final AuthUser? accountUser;
  final VoidCallback onOpenAdmin;
  final VoidCallback onOpenMerchantPortal;
  final VoidCallback onOpenMerchantHub;
  final VoidCallback? onOpenMerchantMenu;
  final int walletBalanceKey;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileStore>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      profile.seedFromAccount(name: accountUser?.name, phone: accountUser?.phone);
    });
    final String displayName = profile.name.isNotEmpty
        ? profile.name
        : (accountUser?.name.isNotEmpty == true ? accountUser!.name : 'สมาชิก ${UiStringsTh.appName}');
    final String displayPhone = profile.phone.isNotEmpty
        ? profile.phone
        : (accountUser?.phone ?? '');
    final String subtitle = displayPhone.isNotEmpty ? '$displayPhone · แตะแก้ไขโปรไฟล์' : 'แตะเพื่อแก้ไขโปรไฟล์';
    return ColoredBox(
      color: AppColors.canvas,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: AppColors.surface,
                elevation: 1,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onHomeTap('demo:profile'),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _ProfileAvatar(
                          dataUrl: profile.avatarDataUrl,
                          frameId: profile.avatarFrameId,
                          verified: profile.verificationStatus.isVerified,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (profile.verificationStatus.isVerified) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF2ECC71)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _BalancePointsRow(onHomeTap: onHomeTap, refreshKey: walletBalanceKey),
              const SizedBox(height: 18),
              _AccountSectionCard(
                children: [
                  _AccountRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'ออเดอร์ของฉัน',
                    subtitle: 'ดูประวัติและสถานะ',
                    onTap: onOpenOrders,
                  ),
                  const _AccountRowDivider(),
                  _AccountRow(
                    icon: Icons.payment_rounded,
                    title: 'การชำระเงิน',
                    subtitle: 'บัตร พร้อมเพย์ กระเป๋าเงิน',
                    onTap: () => onHomeTap('demo:payment'),
                  ),
                  const _AccountRowDivider(),
                  _AccountRow(
                    icon: Icons.bookmark_outline_rounded,
                    title: 'ที่อยู่ที่บันทึก',
                    subtitle: 'บ้าน ที่ทำงาน จุดโปรด',
                    onTap: () => onHomeTap('demo:saved_places'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _AccountSectionCard(
                children: [
                  _AccountRow(
                    icon: Icons.headset_mic_outlined,
                    title: 'ศูนย์ช่วยเหลือ',
                    subtitle: 'คำถามที่พบบ่อย และแชท',
                    onTap: () => onHomeTap('demo:help_centre'),
                  ),
                  const _AccountRowDivider(),
                  _AccountRow(
                    icon: Icons.settings_outlined,
                    title: 'ตั้งค่า',
                    subtitle: 'การแจ้งเตือน และความเป็นส่วนตัว',
                    onTap: () => onHomeTap('demo:settings'),
                  ),
                  const _AccountRowDivider(),
                  _AccountRow(
                    icon: Icons.info_outline_rounded,
                    title: 'เกี่ยวกับแอป',
                    subtitle: 'เวอร์ชันสาธิต',
                    onTap: () => onHomeTap('demo:about'),
                  ),
                ],
              ),
              if (AppConfig.useApi && accountUser?.role == 'admin') ...[
                const SizedBox(height: 14),
                _AccountSectionCard(
                  children: [
                    _AccountRow(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'แผงผู้ดูแลระบบ',
                      subtitle: 'อนุมัติร้าน จัดการผู้ใช้ และร้านรออนุมัติ',
                      onTap: onOpenAdmin,
                    ),
                  ],
                ),
              ],
              if (AppConfig.useApi &&
                  (accountUser?.role == 'customer' ||
                      accountUser?.role == 'merchant_applicant' ||
                      accountUser?.role == 'merchant')) ...[
                const SizedBox(height: 14),
                _AccountSectionCard(
                  children: [
                    _AccountRow(
                      icon: Icons.store_mall_directory_outlined,
                      title: accountUser?.role == 'merchant_applicant'
                          ? 'สถานะคำขอเปิดร้าน'
                          : accountUser?.role == 'merchant'
                              ? 'ศูนย์ร้านค้า'
                              : 'ลงทะเบียนขายอาหารกับ ${UiStringsTh.appName}',
                      subtitle: accountUser?.role == 'merchant_applicant'
                          ? 'รอทีมงานอนุมัติ — รหัสร้านตรงกับที่ลูกค้าสั่ง'
                          : accountUser?.role == 'merchant'
                              ? 'ลงทะเบียน ดูสถานะ และลิงก์จัดการเมนู'
                              : 'ส่งคำขอเพื่อให้ร้านปรากฏในหน้าสั่งอาหาร',
                      onTap: onOpenMerchantHub,
                    ),
                    if (accountUser?.role == 'merchant' && onOpenMerchantMenu != null) ...[
                      const _AccountRowDivider(),
                      _AccountRow(
                        icon: Icons.restaurant_menu_outlined,
                        title: 'จัดการเมนูและหมวดหมู่',
                        subtitle: 'รูป ราคา รายละเอียด — เพิ่มได้ไม่จำกัด',
                        onTap: onOpenMerchantMenu!,
                      ),
                    ],
                  ],
                ),
              ],
              if (AppConfig.useApi && accountUser?.role == 'merchant') ...[
                const SizedBox(height: 14),
                _AccountSectionCard(
                  children: [
                    _AccountRow(
                      icon: Icons.storefront_outlined,
                      title: 'แผงร้านค้า',
                      subtitle: 'ออเดอร์จากลูกค้า',
                      onTap: onOpenMerchantPortal,
                    ),
                  ],
                ),
              ],
              if (!AppConfig.useApi || AppLogoutScope.isInSession(context)) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      AppLogoutScope.logoutOrDemoExit(context);
                    },
                    icon: const Icon(Icons.logout_rounded, size: 22),
                    label: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE3001B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// รูปโปรไฟล์ในแถวบัญชี — แสดงรูปที่ผู้ใช้เลือก (พร้อมกรอบ) หรือ "IN" เมื่อยังไม่มีรูป
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.dataUrl, this.frameId = 'none', this.verified = false});

  final String? dataUrl;
  final String frameId;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (dataUrl != null && dataUrl!.isNotEmpty) {
      try {
        final int i = dataUrl!.indexOf(',');
        final String b64 = i >= 0 ? dataUrl!.substring(i + 1) : dataUrl!;
        inner = Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _initials(),
        );
      } catch (_) {
        inner = _initials();
      }
    } else {
      inner = _initials();
    }
    return FramedAvatar(
      size: 60,
      frame: AvatarFrameInfo.fromId(frameId),
      gapColor: AppColors.surface,
      child: inner,
    );
  }

  Widget _initials() {
    return Container(
      color: AppColors.accentSoft,
      alignment: Alignment.center,
      child: const Text(
        'IN',
        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE3001B), fontSize: 16),
      ),
    );
  }
}

class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(14),
      child: Column(children: children),
    );
  }
}

class _AccountRowDivider extends StatelessWidget {
  const _AccountRowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.border.withValues(alpha: 0.55), indent: 54);
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OrdersTabView extends StatelessWidget {
  const _OrdersTabView({required this.merchants});

  final List<RegisteredMerchant> merchants;

  RegisteredMerchant? _resolveMerchant(PlacedOrder order) {
    for (final RegisteredMerchant m in merchants) {
      if (m.name == order.merchant.name) {
        return m;
      }
    }
    return findMerchantByName(order.merchant.name);
  }

  void _reorder(BuildContext context, PlacedOrder order) {
    final RegisteredMerchant? m = _resolveMerchant(order);
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบร้านนี้ในระบบแล้ว'),
          backgroundColor: Color(0xFFE3001B),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MerchantListScreen(
          merchants: merchants,
          reorderTarget: order,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = OrderStore.ordersForDisplay();
    return ColoredBox(
      color: AppColors.canvas,
      child: orders.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีออเดอร์\nสั่งอาหารจากหน้าแรกได้เลย',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final PlacedOrder o = orders[index];
                return _OrderHistoryCard(
                  order: o,
                  onReorder: o.isActive ? null : () => _reorder(context, o),
                );
              },
            ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({
    required this.order,
    required this.onReorder,
  });

  final PlacedOrder order;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final bool active = order.isActive;
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.merchant.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatOrderDate(order.placedAt),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFFE8EA) : const Color(0xFFECEEF2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? const Color(0xFFE3001B) : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: active ? const Color(0xFFE3001B) : const Color(0xFF3D3D3D),
                    ),
                  ),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 8),
              Text(
                order.pickupMode ? 'รับที่ร้าน' : 'ส่งถึงที่',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...order.lines.map(
              (OrderLine line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.itemName} × ${line.qty}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '฿${line.unitPrice * line.qty}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFFB80012),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'ยอดรวม',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
                const Spacer(),
                Text(
                  '฿${order.totalBaht}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (onReorder != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onReorder,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.topBar,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'สั่งอีกครั้ง',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatOrderDate(DateTime d) {
  final String dd = d.day.toString().padLeft(2, '0');
  final String mm = d.month.toString().padLeft(2, '0');
  final String hh = d.hour.toString().padLeft(2, '0');
  final String min = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year} · $hh:$min น.';
}

class _GrabSearchPill extends StatelessWidget {
  const _GrabSearchPill({required this.onHomeTap});

  final ValueChanged<String> onHomeTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      color: AppColors.surface,
      child: InkWell(
        onTap: () => onHomeTap('search'),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ค้นหาในแอป ${UiStringsTh.appName}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 22,
                color: AppColors.border,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onHomeTap('qr'),
                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrabServiceRow extends StatelessWidget {
  const _GrabServiceRow({
    required this.onHomeTap,
    required this.onOpenFoodOrdering,
    required this.onOpenMart,
    required this.iconCircleBg,
    required this.accentRed,
  });

  final ValueChanged<String> onHomeTap;
  final VoidCallback onOpenFoodOrdering;
  final VoidCallback onOpenMart;
  final Color iconCircleBg;
  final Color accentRed;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.restaurant_rounded,
        label: 'อาหาร',
        onTap: onOpenFoodOrdering,
      ),
      (
        icon: Icons.shopping_basket_rounded,
        label: UiStringsTh.mart,
        onTap: onOpenMart,
      ),
      (
        icon: Icons.local_shipping_rounded,
        label: 'ส่งด่วน',
        onTap: () => onHomeTap('demo:express'),
      ),
      (
        icon: Icons.percent_rounded,
        label: 'โปรโมชัน',
        onTap: () => onHomeTap('demo:promo'),
      ),
      (
        icon: Icons.directions_car_filled_rounded,
        label: 'เดินทาง',
        onTap: () => onHomeTap('demo:travel'),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _GrabServiceChip(
              icon: items[i].icon,
              label: items[i].label,
              iconBg: iconCircleBg,
              iconColor: accentRed,
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _GrabServiceChip extends StatelessWidget {
  const _GrabServiceChip({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.labelMaxLines = 1,
  });

  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
  final int labelMaxLines;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: labelMaxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF424242),
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancePointsRow extends StatelessWidget {
  const _BalancePointsRow({required this.onHomeTap, required this.refreshKey});

  final ValueChanged<String> onHomeTap;
  final int refreshKey;

  @override
  Widget build(BuildContext context) {
    final wallet = context.read<WalletRepository>();
    return FutureBuilder<WalletBalance>(
      key: ValueKey<int>(refreshKey),
      future: wallet.balance(),
      builder: (context, snap) {
        final bal = snap.data?.balanceBaht ?? 500.80;
        final formatted = bal.toStringAsFixed(2);
        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'ยอดคงเหลือ',
                value: '฿ $formatted',
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8EA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFE3001B), size: 22),
                ),
                onTap: () => onHomeTap('demo:wallet'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'ใช้คะแนน',
                value: '3,800',
                trailing: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFC9A227), size: 32),
                onTap: () => onHomeTap('demo:points'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String value;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoVideoAd {
  const _PromoVideoAd({
    required this.videoUrl,
    required this.title,
    required this.subtitle,
    required this.tapId,
    required this.fallbackColors,
  });

  final String videoUrl;
  final String title;
  final String subtitle;
  final String tapId;
  final List<Color> fallbackColors;
}

class _GrabPromoSection extends StatefulWidget {
  const _GrabPromoSection({required this.onHomeTap});

  final ValueChanged<String> onHomeTap;

  @override
  State<_GrabPromoSection> createState() => _GrabPromoSectionState();
}

class _GrabPromoSectionState extends State<_GrabPromoSection> {
  static const _ads = <_PromoVideoAd>[
    _PromoVideoAd(
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      title: 'ส่งฟรี 3 กม.',
      subtitle: 'เฉพาะร้านที่ร่วมรายการ',
      tapId: 'demo:promo_ship',
      fallbackColors: [Color(0xFFE3001B), Color(0xFFFF4D5E)],
    ),
    _PromoVideoAd(
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      title: 'ลดสูงสุด 60%',
      subtitle: UiStringsTh.flashDealSubtitle,
      tapId: 'demo:promo_60',
      fallbackColors: [Color(0xFF8A000D), Color(0xFFE3001B)],
    ),
    _PromoVideoAd(
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      title: 'สมาชิกใหม่',
      subtitle: 'รับคูปองพิเศษวันนี้',
      tapId: 'demo:promo_new',
      fallbackColors: [Color(0xFF1A1A1A), Color(0xFF3D3D3D)],
    ),
  ];

  late final PageController _pageController;
  final List<VideoPlayerController?> _controllers =
      List<VideoPlayerController?>.filled(_ads.length, null);
  final List<bool> _ready = List<bool>.filled(_ads.length, false);
  Timer? _autoTimer;
  int _currentPage = 0;
  bool _userDragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
    _initVideos();
    _startAutoAdvance();
  }

  Future<void> _initVideos() async {
    for (var i = 0; i < _ads.length; i++) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_ads[i].videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controllers[i] = controller;
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        if (!mounted) return;
        setState(() => _ready[i] = true);
        if (i == _currentPage) {
          unawaited(controller.play());
        }
      } catch (_) {
        // Keep gradient fallback if the network video fails to load.
      }
    }
  }

  void _startAutoAdvance() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _userDragging || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _ads.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    for (var i = 0; i < _controllers.length; i++) {
      final c = _controllers[i];
      if (c == null || !_ready[i]) continue;
      if (i == index) {
        unawaited(c.play());
      } else {
        unawaited(c.pause());
      }
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    for (final c in _controllers) {
      c?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () => widget.onHomeTap('demo:promos_all'),
            child: Row(
              children: const [
                Text(
                  UiStringsTh.promoSectionTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textPrimary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _userDragging = true;
                _autoTimer?.cancel();
              } else if (notification is ScrollEndNotification) {
                _userDragging = false;
                _startAutoAdvance();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              padEnds: false,
              itemCount: _ads.length,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final ad = _ads[index];
                final controller = _controllers[index];
                final ready = _ready[index] && controller != null;
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 0,
                    right: 12,
                  ),
                  child: _PromoVideoBannerCard(
                    ad: ad,
                    controller: ready ? controller : null,
                    onTap: () => widget.onHomeTap(ad.tapId),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(_ads.length, (index) {
            final active = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoVideoBannerCard extends StatelessWidget {
  const _PromoVideoBannerCard({
    required this.ad,
    required this.controller,
    required this.onTap,
  });

  final _PromoVideoAd ad;
  final VideoPlayerController? controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasVideo = controller != null && controller!.value.isInitialized;

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: Colors.black,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ad.fallbackColors,
                ),
              ),
            ),
            if (hasVideo)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller!.value.size.height,
                  child: VideoPlayer(controller!),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x99000000),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'โฆษณา',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyShopsSectionLight extends StatelessWidget {
  const _NearbyShopsSectionLight({required this.merchants, required this.onPreviewShop});

  final List<RegisteredMerchant> merchants;
  final ValueChanged<RegisteredMerchant> onPreviewShop;

  @override
  Widget build(BuildContext context) {
    final nearbyShops = List<RegisteredMerchant>.from(merchants)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    final shops = nearbyShops.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ร้านใกล้คุณ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...shops.map(
          (shop) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              elevation: 1,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () => onPreviewShop(shop),
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: const Icon(Icons.store_rounded, color: Color(0xFFE3001B)),
                ),
                title: Text(
                  shop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'เวลาส่งโดยประมาณ ${shop.etaMinutes} นาที',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantBrowseCard extends StatelessWidget {
  const _RestaurantBrowseCard({
    required this.merchant,
    required this.onTap,
  });

  final RegisteredMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tags = mockMerchantTags(merchant);
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                merchant.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => Container(
                  color: const Color(0xFFECEEF2),
                  alignment: Alignment.center,
                  child: const Icon(Icons.restaurant, size: 48, color: Colors.black26),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 20),
                      const SizedBox(width: 2),
                      Text(
                        merchant.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${merchant.usageCount})',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'สั่งขั้นต่ำ ฿${mockMinOrderBaht(merchant)}  ·  ค่าส่ง ฿${merchant.deliveryFee}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                              color: AppColors.surfaceElevated,
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryPickupBar extends StatelessWidget {
  const _DeliveryPickupBar({
    required this.mode,
    required this.onChanged,
  });

  /// 0 = ส่งถึงที่, 1 = รับที่ร้าน
  final int mode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'ส่งถึงที่',
                  selected: mode == 0,
                  onTap: () => onChanged(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeChip(
                  label: 'รับที่ร้าน',
                  selected: mode == 1,
                  onTap: () => onChanged(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _red = Color(0xFFE3001B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _red : const Color(0xFFF3F4F7),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
                color: selected ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// หมวด Mart ตามลำดับที่กำหนด: ห้าง → ร้านขายของสด → ของใช้ทั่วไป → ซุปเปอร์มาเก็ต → ทุกร้าน
enum MartCategoryKind {
  mall,
  freshShop,
  general,
  supermarket,
  all,
}

class MartOutlet {
  const MartOutlet({
    required this.name,
    required this.kind,
    required this.imageUrl,
    required this.etaMinutes,
    required this.distanceKm,
    required this.rating,
    required this.promoLine,
    this.showPromoRibbon = false,
    this.extraPromoTags = const <String>[],
  });

  final String name;
  final MartCategoryKind kind;
  final String imageUrl;
  final int etaMinutes;
  final double distanceKm;
  final double rating;
  final String promoLine;
  final bool showPromoRibbon;
  final List<String> extraPromoTags;
}

const List<MartOutlet> _kMartOutlets = <MartOutlet>[
  MartOutlet(
    name: 'เซ็นทรัล ฟู้ดฮอลล์',
    kind: MartCategoryKind.mall,
    imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=600&q=80',
    etaMinutes: 28,
    distanceKm: 2.4,
    rating: 4.8,
    promoLine: 'ลด 15%',
  ),
  MartOutlet(
    name: 'อิเกีย เมกาบางนา',
    kind: MartCategoryKind.mall,
    imageUrl: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=600&q=80',
    etaMinutes: 35,
    distanceKm: 5.1,
    rating: 4.6,
    promoLine: 'คูปองลด 10%',
  ),
  MartOutlet(
    name: 'ตลาดสดบางรัก',
    kind: MartCategoryKind.freshShop,
    imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600&q=80',
    etaMinutes: 18,
    distanceKm: 0.9,
    rating: 4.5,
    promoLine: 'สดใหม่ทุกวัน',
  ),
  MartOutlet(
    name: 'ร้านเนื้อวากิวโดยตรง',
    kind: MartCategoryKind.freshShop,
    imageUrl: 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=600&q=80',
    etaMinutes: 22,
    distanceKm: 1.6,
    rating: 4.7,
    promoLine: 'ลด 12%',
  ),
  MartOutlet(
    name: 'ไดโซ สไตล์',
    kind: MartCategoryKind.general,
    imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600&q=80',
    etaMinutes: 24,
    distanceKm: 2.0,
    rating: 4.4,
    promoLine: 'ของใช้เริ่ม 20 บ.',
  ),
  MartOutlet(
    name: 'มินิมาร์ท 24 ชม.',
    kind: MartCategoryKind.general,
    imageUrl: 'https://images.unsplash.com/photo-1583258292688-d5f578036c82?w=600&q=80',
    etaMinutes: 15,
    distanceKm: 0.6,
    rating: 4.3,
    promoLine: 'ส่งฟรีขั้นต่ำ',
  ),
  MartOutlet(
    name: UiStringsTh.outletLotusFresh,
    kind: MartCategoryKind.supermarket,
    imageUrl: 'https://images.unsplash.com/photo-1578916171728-46688e847d20?w=600&q=80',
    etaMinutes: 20,
    distanceKm: 1.4,
    rating: 4.6,
    promoLine: 'ลด 20%',
    showPromoRibbon: true,
    extraPromoTags: <String>['ลด 25%', 'ลด 20%'],
  ),
  MartOutlet(
    name: UiStringsTh.outletBigC,
    kind: MartCategoryKind.supermarket,
    imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=600&q=80',
    etaMinutes: 26,
    distanceKm: 3.0,
    rating: 4.5,
    promoLine: UiStringsTh.payWeek,
    showPromoRibbon: true,
    extraPromoTags: <String>['ลด 20%'],
  ),
  MartOutlet(
    name: 'ท็อปส์ ฟู้ด ฮอลล์',
    kind: MartCategoryKind.supermarket,
    imageUrl: 'https://images.unsplash.com/photo-1534723452862-4c18ecf7d14b?w=600&q=80',
    etaMinutes: 22,
    distanceKm: 1.9,
    rating: 4.7,
    promoLine: 'ลดเพิ่ม 18%',
  ),
];

class MartProductSection {
  const MartProductSection({required this.title, required this.items});

  final String title;
  final List<FoodMenuItem> items;
}

RegisteredMerchant registeredMerchantFromMartOutlet(MartOutlet o) {
  final String cat = switch (o.kind) {
    MartCategoryKind.freshShop => UiStringsTh.martCatFresh,
    MartCategoryKind.supermarket => UiStringsTh.martCatSuper,
    MartCategoryKind.mall => UiStringsTh.martCatMall,
    MartCategoryKind.general => UiStringsTh.martCatGeneral,
    MartCategoryKind.all => UiStringsTh.martCatAll,
  };
  final slug = 'mart-${o.name.replaceAll(RegExp(r'\s+'), '-').toLowerCase()}';
  return RegisteredMerchant(
    slug: slug,
    name: o.name,
    category: cat,
    etaMinutes: o.etaMinutes,
    rating: o.rating,
    usageCount: 880,
    imageUrl: o.imageUrl,
    distanceKm: o.distanceKm,
    deliveryFee: o.distanceKm >= 2.5 ? 25 : (o.distanceKm >= 1.5 ? 15 : 0),
  );
}

/// ร้านของสด = แนวตามหมวดแนวนอน (รูปที่ 1) · ซุปเปอร์/ห้าง/ของใช้ = กริดหมวด + แนวร้านค้า (รูปที่ 2)
List<MartProductSection> martProductSectionsForOutlet(MartOutlet outlet) {
  if (outlet.kind == MartCategoryKind.freshShop) {
    return <MartProductSection>[
      const MartProductSection(
        title: 'สำหรับคุณ',
        items: <FoodMenuItem>[
          FoodMenuItem(
            name: 'เนื้อเต๋าหมักน้ำมันงา',
            price: 239,
            description: '500g · เนื้อดรายเอจ',
            imageUrl: 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=800&q=80',
          ),
          FoodMenuItem(
            name: 'เนื้อวากิวสันนอก เกรด A5',
            price: 890,
            description: '200g · แช่แข็งส่งเย็น',
            imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
          ),
        ],
      ),
      const MartProductSection(
        title: 'เนื้อสเต็กโคขุน',
        items: <FoodMenuItem>[
          FoodMenuItem(
            name: 'สเต็กโคขุนส่วนริบอาย',
            price: 329,
            description: '350g',
            imageUrl: 'https://images.unsplash.com/photo-1558030006-450675393462?w=800&q=80',
          ),
          FoodMenuItem(
            name: 'สเต็กเนื้อสันทอนเดอร์',
            price: 399,
            description: '300g',
            imageUrl: 'https://images.unsplash.com/photo-1588167056541-8cbb106e9e1b?w=800&q=80',
          ),
        ],
      ),
      const MartProductSection(
        title: 'เนื้อหมักพร้อมปรุง',
        items: <FoodMenuItem>[
          FoodMenuItem(
            name: 'หมูสามชั้นหมักเกาหลี',
            price: 159,
            description: '400g',
            imageUrl: 'https://images.unsplash.com/photo-1602470520998-f4a29683e081?w=800&q=80',
          ),
          FoodMenuItem(
            name: 'เนื้อหมักงาญี่ปุ่น ยากินิกุ',
            price: 219,
            description: '350g',
            imageUrl: 'https://images.unsplash.com/photo-1594041680534-e8c8cdebd659?w=800&q=80',
          ),
        ],
      ),
      const MartProductSection(
        title: 'ผักและเครื่องเคียง',
        items: <FoodMenuItem>[
          FoodMenuItem(
            name: 'ผักสลัดรวมพรีเมียม',
            price: 89,
            description: '250g',
            imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80',
          ),
          FoodMenuItem(
            name: 'เห็ดชิเมจิ',
            price: 49,
            description: '150g',
            imageUrl: 'https://images.unsplash.com/photo-1564671545904-61ff19e86d43?w=800&q=80',
          ),
        ],
      ),
    ];
  }

  return <MartProductSection>[
    const MartProductSection(
      title: 'ไอศกรีม',
      items: <FoodMenuItem>[
        FoodMenuItem(
          name: 'ไอศกรีมรสวานิลา ถังเล็ก',
          price: 129,
          description: '450 ml',
          imageUrl: 'https://images.unsplash.com/photo-1560008581-09826d1de69e?w=800&q=80',
        ),
        FoodMenuItem(
          name: 'ไอศกรีมรสช็อกโกแลต',
          price: 119,
          description: '450 ml',
          imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&q=80',
        ),
      ],
    ),
    const MartProductSection(
      title: 'เครื่องดื่ม',
      items: <FoodMenuItem>[
        FoodMenuItem(
          name: 'น้ำดื่มแพ็ก 6 ขวด',
          price: 55,
          description: '6 x 1.5L',
          imageUrl: 'https://images.unsplash.com/photo-1523362628745-0c100150b364?w=800&q=80',
        ),
        FoodMenuItem(
          name: 'น้ำส้มคั้นสด',
          price: 69,
          description: '1L',
          imageUrl: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=800&q=80',
        ),
      ],
    ),
    const MartProductSection(
      title: 'นมและไข่',
      items: <FoodMenuItem>[
        FoodMenuItem(
          name: 'นม UHT รสจืด',
          price: 42,
          description: '1L',
          imageUrl: 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=800&q=80',
        ),
        FoodMenuItem(
          name: 'ไข่ไก่เบอร์ 0',
          price: 65,
          description: '10 ฟอง',
          imageUrl: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=800&q=80',
        ),
      ],
    ),
    const MartProductSection(
      title: 'ของแห้งและเครื่องปรุง',
      items: <FoodMenuItem>[
        FoodMenuItem(
          name: 'ข้าวหอมมะลิ 5 กก.',
          price: 259,
          description: 'ถุง',
          imageUrl: 'https://images.unsplash.com/photo-1586201370761-83862ca3e499?w=800&q=80',
        ),
        FoodMenuItem(
          name: 'ซอสถั่วเหลือง',
          price: 35,
          description: '700 ml',
          imageUrl: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&q=80',
        ),
      ],
    ),
    const MartProductSection(
      title: 'ขนมและของขบเคี้ยว',
      items: <FoodMenuItem>[
        FoodMenuItem(
          name: 'มันฝรั่งทอดกรอบ',
          price: 49,
          description: 'แพ็ก',
          imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=800&q=80',
        ),
        FoodMenuItem(
          name: 'ช็อกโกแลตแท่ง',
          price: 29,
          description: '50g',
          imageUrl: 'https://images.unsplash.com/photo-1511381939415-e44015466834?w=800&q=80',
        ),
      ],
    ),
    const MartProductSection(
      title: 'เนื้อสัตว์และอาหารทะเล',
      items: <FoodMenuItem>[
        FoodMenuItem(
          name: 'กุ้งแชบ๊วยแช่แข็ง',
          price: 189,
          description: '500g',
          imageUrl: 'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=800&q=80',
        ),
        FoodMenuItem(
          name: 'อกไก่สด',
          price: 99,
          description: '500g',
          imageUrl: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=800&q=80',
        ),
      ],
    ),
  ];
}

bool martStoreUsesFreshLayout(MartOutlet outlet) => outlet.kind == MartCategoryKind.freshShop;

class MartStoreDetailScreen extends StatefulWidget {
  const MartStoreDetailScreen({super.key, required this.outlet});

  final MartOutlet outlet;

  @override
  State<MartStoreDetailScreen> createState() => _MartStoreDetailScreenState();
}

class _MartStoreDetailScreenState extends State<MartStoreDetailScreen> {
  static const Color _red = Color(0xFFE3001B);
  static const Color _priceText = Color(0xFFB80012);

  late final RegisteredMerchant _merchant = registeredMerchantFromMartOutlet(widget.outlet);
  late final List<MartProductSection> _sections = martProductSectionsForOutlet(widget.outlet);
  late final List<FoodMenuItem> _items;
  late List<int> _qty;

  bool get _freshLayout => martStoreUsesFreshLayout(widget.outlet);

  @override
  void initState() {
    super.initState();
    _items = _sections.expand((MartProductSection s) => s.items).toList(growable: false);
    _qty = List<int>.filled(_items.length, 0);
  }

  int get _cartPieces => _qty.fold(0, (int a, int b) => a + b);

  int get _cartTotalBaht {
    var sum = 0;
    for (var i = 0; i < _items.length; i++) {
      sum += _items[i].price * _qty[i];
    }
    return sum;
  }

  void _setQty(int index, int value) {
    final next = value.clamp(0, 99);
    if (_qty[index] == next) {
      return;
    }
    setState(() => _qty[index] = next);
  }

  Future<void> _onCartBarTap() async {
    if (_cartTotalBaht <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกจำนวนสินค้าก่อน'),
          backgroundColor: Color(0xFFE3001B),
        ),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (BuildContext context) => _DeliveryTimeSheet(
        merchant: _merchant,
        pickupMode: false,
      ),
    );
    if (!mounted || ok != true) {
      return;
    }
    final breakdown = estimateDeliveryPhases(_merchant, pickupMode: false);
    final List<OrderLine> lines = <OrderLine>[];
    for (var i = 0; i < _items.length; i++) {
      if (_qty[i] <= 0) {
        continue;
      }
      lines.add(
        OrderLine(
          itemName: _items[i].name,
          unitPrice: _items[i].price,
          qty: _qty[i],
        ),
      );
    }
    String? paymentIntentId;
    final paid = await showPaymentCheckout(
      context,
      amountBaht: _cartTotalBaht,
      purpose: 'order',
    );
    if (paid == null || !paid.isSucceeded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังไม่ได้ชำระเงินสำเร็จ')),
        );
      }
      return;
    }
    paymentIntentId = paid.id;
    final String tentativeId = 'ord-${DateTime.now().millisecondsSinceEpoch}';
    final String orderId = await OrderStore.addOrder(
      PlacedOrder(
        id: tentativeId,
        placedAt: DateTime.now(),
        merchant: _merchant,
        lines: lines,
        totalBaht: _cartTotalBaht,
        deliveryBreakdown: breakdown,
        pickupMode: false,
        statusLabel: 'กำลังจัดส่ง',
        paymentIntentId: paymentIntentId,
      ),
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OrderTrackingScreen(
          merchant: _merchant,
          totalBaht: _cartTotalBaht,
          etaMinutes: breakdown.totalMinutes,
          pickupMode: false,
          deliveryBreakdown: breakdown,
        ),
      ),
    );
    if (mounted) {
      await OrderStore.markCompleted(orderId);
    }
  }

  Widget _qtyRow(int index) {
    final q = _qty[index];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceElevated,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: q > 0 ? () => _setQty(index, q - 1) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(36, 36),
              maximumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: q > 0 ? const Color(0xFF0D0D0D) : const Color(0xFF9E9E9E),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF9E9E9E),
              shape: const CircleBorder(),
              elevation: q > 0 ? 1 : 0,
            ),
            child: const Icon(Icons.remove_rounded, size: 20),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$q',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          FilledButton(
            onPressed: () => _setQty(index, q + 1),
            style: FilledButton.styleFrom(
              minimumSize: const Size(36, 36),
              maximumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xFFDA0018),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
            ),
            child: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _freshProductCard(FoodMenuItem item, int index) {
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _foodItemImage(item.imageUrl, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _qtyRow(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '฿${item.price}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _priceText),
          ),
          const SizedBox(height: 2),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            item.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _supermarketCategoryGrid() {
    const tiles = <({IconData icon, String label})>[
      (icon: Icons.icecream_outlined, label: 'ไอศกรีม'),
      (icon: Icons.local_cafe_outlined, label: 'เครื่องดื่ม'),
      (icon: Icons.egg_outlined, label: 'นมและไข่'),
      (icon: Icons.ramen_dining_outlined, label: 'ของแห้ง'),
      (icon: Icons.cleaning_services_outlined, label: 'ของใช้ในบ้าน'),
      (icon: Icons.eco_outlined, label: 'ผักและผลไม้'),
      (icon: Icons.cookie_outlined, label: 'ขนม'),
      (icon: Icons.spa_outlined, label: 'ดูแลตัวเอง'),
      (icon: Icons.ac_unit_outlined, label: 'แช่แข็ง'),
      (icon: Icons.restaurant_outlined, label: 'พร้อมทาน'),
      (icon: Icons.set_meal_outlined, label: 'เนื้อ/ทะเล'),
      (icon: Icons.grid_view_rounded, label: 'ดูทั้งหมด'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: tiles.length,
      itemBuilder: (BuildContext context, int i) {
        final t = tiles[i];
        return Material(
          color: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
          ),
          child: InkWell(
            onTap: () {
              showDemoInfoSheet(
                context,
                title: 'หมวด ${t.label}',
                paragraphs: const <String>[
                  'เลื่อนลงด้านล่างเพื่อดูสินค้าในหมวดที่เกี่ยวข้อง',
                  'แตะสินค้าแล้วใช้ปุ่ม + / − เพื่อใส่ตะกร้า',
                ],
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, size: 32, color: Colors.white),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    t.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreshScroll() {
    final o = widget.outlet;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.network(
                  o.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: AppColors.surface),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 56,
                left: 72,
                child: TextField(
                  readOnly: true,
                  onTap: () {
                    showDemoInfoSheet(
                      context,
                      title: 'ค้นหาสินค้า',
                      paragraphs: const <String>[
                        'พิมพ์ชื่อสินค้าเพื่อกรองรายการ (เวอร์ชันจริงจะเชื่อมคลังสินค้า)',
                        'ตอนนี้เลื่อนดูสินค้าตามหมวดด้านล่างได้ทันที',
                      ],
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'ค้นหาสินค้า',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w500),
                    prefixIcon: Icon(Icons.search_rounded, size: 22, color: Colors.white.withValues(alpha: 0.9)),
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.88),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: -56,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 20),
                            Text(
                              '${o.rating.toStringAsFixed(1)} (128) · เรตติ้งและรีวิว',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.delivery_dining_rounded, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${o.distanceKm} กม. (${o.etaMinutes} นาที ขึ้นไป)',
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              'ส่งฟรี',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 68)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              children: [
                _FreshPromoChip(label: 'ลด 20%', bg: AppColors.surfaceElevated, fg: Colors.white),
                const SizedBox(width: 8),
                _FreshPromoChip(label: UiStringsTh.payWeek, bg: AppColors.surfaceElevated, fg: Colors.white),
                const SizedBox(width: 8),
                _FreshPromoChip(label: UiStringsTh.saverDelivery, bg: AppColors.surfaceElevated, fg: Colors.white),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              children: [
                for (final s in _sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        s.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                      ),
                      onPressed: () {
                        showDemoInfoSheet(
                          context,
                          title: s.title,
                          paragraphs: const <String>[
                            'เลื่อนลงเพื่อดูแถวสินค้าของหมวดนี้',
                            'แตะรูปสินค้าแล้วปรับจำนวนที่มุมการ์ด',
                          ],
                        );
                      },
                      backgroundColor: AppColors.surfaceElevated,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ..._buildFreshSectionSlivers(),
      ],
    );
  }

  List<Widget> _buildFreshSectionSlivers() {
    var flat = 0;
    final out = <Widget>[];
    for (final MartProductSection sec in _sections) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sec.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
      out.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: sec.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int j) {
                final idx = flat++;
                return _freshProductCard(sec.items[j], idx);
              },
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _buildSupermarketScroll() {
    final o = widget.outlet;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  o.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF3A3A3A)),
                ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.black.withValues(alpha: 0.35)),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 4,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: TextField(
                    readOnly: true,
                    onTap: () {
                      showDemoInfoSheet(
                        context,
                        title: 'ค้นหาสินค้า',
                        paragraphs: const <String>[
                          'ค้นหาจากชื่อสินค้าในหมวดด้านล่าง',
                          'เวอร์ชันจริงจะมีประวัติการค้นหาและข้อเสนอ',
                        ],
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'ค้นหาสินค้า',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      suffixIcon: const Icon(Icons.edit_note_outlined, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFE3001B),
                  child: Text(
                    o.name.isNotEmpty ? o.name.substring(0, 1) : 'M',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'สาขาใกล้คุณ · ${o.distanceKm} กม. · ค่าส่ง ฿${_merchant.deliveryFee} · ${o.etaMinutes} นาที',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('เปลี่ยน', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              children: [
                _MartPromoMiniCard(title: 'สมาชิกลดเพิ่ม', subtitle: 'สูงสุด 15%', accent: const Color(0xFF81C784)),
                const SizedBox(width: 10),
                _MartPromoMiniCard(title: UiStringsTh.payWeek, subtitle: 'ลด 25%', accent: const Color(0xFFE3001B)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Material(
              color: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
              ),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ดีลแรง ลดจริง คลิกเลย!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              UiStringsTh.shopNow,
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          UiStringsTh.saleBadge,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'ส่งรายการช้อปให้ร้านจัดให้ — วางใจได้ทั้งของสดและของใช้',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _supermarketCategoryGrid()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'สินค้าแนะนำ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
          ),
        ),
        ..._buildSupermarketProductSlivers(),
      ],
    );
  }

  List<Widget> _buildSupermarketProductSlivers() {
    var flat = 0;
    final out = <Widget>[];
    for (final MartProductSection sec in _sections) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary)),
          ),
        ),
      );
      out.add(
        SliverToBoxAdapter(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            itemCount: sec.items.length,
            separatorBuilder: (_, _) => Divider(height: 20, color: AppColors.border.withValues(alpha: 0.5)),
            itemBuilder: (BuildContext context, int j) {
              final item = sec.items[j];
              final idx = flat++;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _foodItemImage(item.imageUrl, width: 72, height: 72, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '฿${item.price}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _priceText),
                        ),
                      ],
                    ),
                  ),
                  _qtyRow(idx),
                ],
              );
            },
          ),
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hasCart = _cartTotalBaht > 0;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          Expanded(
            child: _freshLayout ? _buildFreshScroll() : _buildSupermarketScroll(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasCart
                ? Material(
                    key: const ValueKey<String>('mart_cart_on'),
                    color: AppColors.topBar,
                    elevation: 12,
                    shadowColor: Colors.black54,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _onCartBarTap,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                                          Positioned(
                                            right: -8,
                                            top: -8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: const BoxDecoration(
                                                color: _red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '$_cartPieces',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              UiStringsTh.martCart,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '$_cartPieces รายการ · แตะเลือกเวลาส่ง',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.92),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '฿$_cartTotalBaht',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _onCartBarTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDA0018),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Colors.black54,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('ชำระเงิน', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey<String>('mart_cart_off')),
          ),
        ],
      ),
    );
  }
}

class _FreshPromoChip extends StatelessWidget {
  const _FreshPromoChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
      backgroundColor: bg,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _MartPromoMiniCard extends StatelessWidget {
  const _MartPromoMiniCard({required this.title, required this.subtitle, required this.accent});

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: accent)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class MartScreen extends StatefulWidget {
  const MartScreen({super.key});

  @override
  State<MartScreen> createState() => _MartScreenState();
}

class _MartScreenState extends State<MartScreen> {
  static const Color _red = Color(0xFFE3001B);

  MartCategoryKind _selectedKind = MartCategoryKind.mall;

  List<MartOutlet> get _visible {
    if (_selectedKind == MartCategoryKind.all) {
      return List<MartOutlet>.from(_kMartOutlets);
    }
    return _kMartOutlets.where((MartOutlet e) => e.kind == _selectedKind).toList();
  }

  static const List<({MartCategoryKind kind, String label, IconData icon})> _tabs =
      <({MartCategoryKind kind, String label, IconData icon})>[
    (kind: MartCategoryKind.mall, label: 'ห้าง', icon: Icons.store_mall_directory_rounded),
    (kind: MartCategoryKind.freshShop, label: 'ร้านขายของสด', icon: Icons.set_meal_rounded),
    (kind: MartCategoryKind.general, label: 'ของใช้ทั่วไป', icon: Icons.inventory_2_outlined),
    (kind: MartCategoryKind.supermarket, label: 'ซุปเปอร์มาเก็ต', icon: Icons.shopping_cart_outlined),
    (kind: MartCategoryKind.all, label: 'ทุกร้าน', icon: Icons.grid_view_rounded),
  ];

  Future<void> _openFoodMerchantListFromMart() async {
    List<RegisteredMerchant> merchants = <RegisteredMerchant>[];
    try {
      merchants = await context.read<CatalogRepository>().fetchMerchants();
      merchants.sort((RegisteredMerchant a, RegisteredMerchant b) => b.usageCount.compareTo(a.usageCount));
    } catch (_) {}
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MerchantListScreen(merchants: merchants),
      ),
    );
  }

  Widget _lineSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.55), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.55), height: 1)),
        ],
      ),
    );
  }

  Widget _blockTitle(String title, {String? subtitle, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            IconButton(
              onPressed: onSeeAll,
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                backgroundColor: AppColors.surfaceElevated,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(36, 36),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryStrip() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int i) {
          final tab = _tabs[i];
          final selected = _selectedKind == tab.kind;
          return InkWell(
            onTap: () => setState(() => _selectedKind = tab.kind),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.accentSoft : AppColors.surfaceElevated,
                      border: Border.all(
                        color: selected ? _red : AppColors.border,
                        width: 2.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      tab.icon,
                      color: selected ? _red : Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 88,
                    child: Text(
                      tab.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _famousBrandsRow() {
    const brands = <({String abbr, Color bg, Color fg})>[
      (abbr: UiStringsTh.brandTops, bg: Color(0xFFE3001B), fg: Color(0xFFFFFFFF)),
      (abbr: UiStringsTh.brandTfh, bg: Color(0xFF1A1A1A), fg: Color(0xFFFFFFFF)),
      (abbr: UiStringsTh.brandLotus, bg: Color(0xFF00A19A), fg: Color(0xFFFFFFFF)),
      (abbr: UiStringsTh.brandBigC, bg: Color(0xFF00A651), fg: Color(0xFFFFFFFF)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final b in brands)
            Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: b.bg,
                  child: Text(
                    b.abbr,
                    style: TextStyle(
                      color: b.fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  b.abbr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _promoTwoCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _MartPromoCard(
              bg: AppColors.surfaceElevated,
              title: 'รวมร้านค่าส่งถูก',
              subtitle: 'เริ่มต้น 0 บ.*',
              accent: const Color(0xFF81C784),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MartPromoCard(
              bg: AppColors.surfaceElevated,
              title: UiStringsTh.payWeek,
              subtitle: 'ลดเพิ่มสูงสุด 20%',
              accent: _red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalStores(String emptyHint, {bool hitStyle = false, bool smallStyle = false}) {
    final list = _visible;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(emptyHint, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
    }
    return SizedBox(
      height: smallStyle ? 248 : (hitStyle ? 252 : 232),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int i) {
          return _MartStoreTile(
            outlet: list[i],
            hitStyle: hitStyle,
            smallStyle: smallStyle,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: kUnifiedTopBarBg,
        foregroundColor: kUnifiedTopBarFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kUnifiedTopBarToolbarHeight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const _AppBarTitleWithLogo(
          title: UiStringsTh.mart,
          titleStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kUnifiedTopBarFg,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'รายการโปรด',
            onPressed: () {
              showDemoInfoSheet(
                context,
                title: 'ร้านที่ชอบ',
                paragraphs: const <String>[
                  'บันทึกร้าน ${UiStringsTh.mart} และร้านอาหารที่ซื้อบ่อยไว้ที่นี่',
                  'เมื่อเข้าร้าน ${UiStringsTh.mart} แล้วเพิ่มสินค้า ตะกร้าจะอยู่แถบล่างของหน้าร้าน',
                ],
              );
            },
            icon: const Icon(Icons.favorite_border_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'mart_cart_fab',
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 6,
        onPressed: () {
          showDemoInfoSheet(
            context,
            title: UiStringsTh.martCart,
            paragraphs: const <String>[
              'ตะกร้าของแต่ละร้าน ${UiStringsTh.mart} อยู่ที่หน้าร้านเมื่อคุณเลือกสินค้าแล้ว',
              'จากหน้านี้แตะการ์ดร้าน แล้วใช้ปุ่ม + / − และชำระเงินที่แถบล่าง',
            ],
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 26),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3001B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'จัดส่งไปยัง',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'บ้านเลขที่ 88 แขวงบางรัก กรุงเทพฯ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              readOnly: true,
              onTap: () {
                showAppSearchSheet(
                  context,
                  onPickFood: _openFoodMerchantListFromMart,
                  onPickMart: () {},
                );
              },
              decoration: InputDecoration(
                hintText: UiStringsTh.searchMartHint,
                hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          ColoredBox(
            color: AppColors.canvas,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _categoryStrip(),
                _lineSectionTitle('ร้านดังส่งฟรี'),
                _famousBrandsRow(),
                const SizedBox(height: 8),
                _promoTwoCards(),
                const SizedBox(height: 8),
                _blockTitle('สั่งอีกครั้ง'),
                _horizontalStores(
                  'ยังไม่มีร้านในหมวดนี้ — ลองเลือก "ทุกร้าน"',
                ),
                _blockTitle(
                  UiStringsTh.hitItemsTitle,
                  subtitle: 'ใส่โค้ดลดสูงสุด 20%',
                ),
                _horizontalStores(
                  'ยังไม่มีร้านในหมวดนี้',
                  hitStyle: true,
                ),
                _blockTitle(
                  'ร้านเล็กโค้ดลดแรง',
                  subtitle: 'ใส่ SMALL25 ลดเพิ่ม 25%',
                  onSeeAll: () {
                    showDemoInfoSheet(
                      context,
                      title: 'ร้านเล็กโค้ดลดแรง',
                      paragraphs: const <String>[
                        'รวมร้านขนาดเล็กที่เข้าร่วมโค้ด SMALL25',
                        'เลื่อนแนวนอนด้านบนเพื่อดูร้านในหมวดที่เลือก — แตะการ์ดเพื่อเข้าสู่ร้าน',
                      ],
                    );
                  },
                ),
                _horizontalStores(
                  'ยังไม่มีร้านในหมวดนี้',
                  smallStyle: true,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MartPromoCard extends StatelessWidget {
  const _MartPromoCard({
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final Color bg;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        onTap: () {
          showDemoInfoSheet(
            context,
            title: title,
            paragraphs: <String>[
              subtitle,
              'รายละเอียดโปรจะแสดงตามร้านที่ร่วมรายการเมื่อเชื่อมระบบจริง',
            ],
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.delivery_dining_rounded, color: accent.withValues(alpha: 0.45), size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MartStoreTile extends StatelessWidget {
  const _MartStoreTile({
    required this.outlet,
    this.hitStyle = false,
    this.smallStyle = false,
  });

  final MartOutlet outlet;
  final bool hitStyle;
  final bool smallStyle;

  static const Color _red = Color(0xFFE3001B);

  @override
  Widget build(BuildContext context) {
    final w = smallStyle ? 132.0 : 140.0;
    return SizedBox(
      width: w,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => MartStoreDetailScreen(outlet: outlet),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      outlet.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: Icon(Icons.storefront_rounded, size: 40, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  if (outlet.showPromoRibbon && hitStyle)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'โปรโมชัน',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (hitStyle && outlet.showPromoRibbon) ...[
              Row(
                children: [
                  Icon(Icons.local_offer_rounded, size: 14, color: Colors.orange.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'โปรโมชัน',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              outlet.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${outlet.etaMinutes} นาที • ${outlet.distanceKm} กม. • ★ ${outlet.rating}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.sell_outlined, size: 14, color: _red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    outlet.promoLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE3001B),
                    ),
                  ),
                ),
              ],
            ),
            if (hitStyle && outlet.extraPromoTags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final t in outlet.extraPromoTags.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MerchantListScreen extends StatefulWidget {
  const MerchantListScreen({
    super.key,
    required this.merchants,
    this.reorderTarget,
  });

  final List<RegisteredMerchant> merchants;
  final PlacedOrder? reorderTarget;

  @override
  State<MerchantListScreen> createState() => _MerchantListScreenState();
}

class _MerchantListScreenState extends State<MerchantListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ทั้งหมด';
  double _maxDistanceKm = 10;
  int _maxDeliveryFee = 60;
  int _deliveryMode = 0;

  @override
  void initState() {
    super.initState();
    final PlacedOrder? target = widget.reorderTarget;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        RegisteredMerchant? merchant;
        for (final RegisteredMerchant m in widget.merchants) {
          if (m.name == target.merchant.name) {
            merchant = m;
            break;
          }
        }
        merchant ??= findMerchantByName(target.merchant.name);
        if (merchant == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่พบร้านสำหรับสั่งอีกครั้ง'),
              backgroundColor: Color(0xFFE3001B),
            ),
          );
          return;
        }
        final RegisteredMerchant openMerchant = merchant;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => RestaurantDetailScreen(
              merchant: openMerchant,
              menuItems: AppConfig.useApi ? null : menuForMerchant(openMerchant),
              pickupMode: target.pickupMode,
              reorderLines: target.lines,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegisteredMerchant> _filteredMerchants() {
    final keyword = _searchController.text.trim().toLowerCase();
    return widget.merchants.where((merchant) {
      final matchesKeyword = keyword.isEmpty ||
          merchant.name.toLowerCase().contains(keyword) ||
          merchant.category.toLowerCase().contains(keyword);
      final matchesCategory =
          _selectedCategory == 'ทั้งหมด' || merchant.category == _selectedCategory;
      final matchesDistance = merchant.distanceKm <= _maxDistanceKm;
      final matchesFee = merchant.deliveryFee <= _maxDeliveryFee;
      return matchesKeyword && matchesCategory && matchesDistance && matchesFee;
    }).toList();
  }

  void _openMerchant(RegisteredMerchant merchant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RestaurantDetailScreen(
          merchant: merchant,
          menuItems: AppConfig.useApi ? null : menuForMerchant(merchant),
          pickupMode: _deliveryMode == 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMerchants = _filteredMerchants();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: kUnifiedTopBarBg,
        foregroundColor: kUnifiedTopBarFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kUnifiedTopBarToolbarHeight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const _AppBarTitleWithLogo(title: 'สั่งอาหาร'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () {
              showDemoInfoSheet(
                context,
                title: 'ร้านที่ชอบ',
                paragraphs: const <String>[
                  'ดูร้านที่บันทึกไว้และเปิดสั่งซ้ำได้เร็วขึ้น',
                  'ในเวอร์ชันจริงจะซิงก์กับบัญชีของคุณ',
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              physics: const BouncingScrollPhysics(),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ส่งที่',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'บ้านเลขที่ 88 แขวงบางรัก กรุงเทพฯ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        showDemoInfoSheet(
                          context,
                          title: 'ที่อยู่จัดส่ง',
                          paragraphs: const <String>[
                            'เลือกที่อยู่จากรายการที่บันทึก หรือเพิ่มที่อยู่ใหม่',
                            'ตอนนี้ใช้ที่อยู่ตัวอย่าง: บ้านเลขที่ 88 แขวงบางรัก กรุงเทพฯ',
                          ],
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE3001B),
                        side: const BorderSide(color: Color(0xFFE3001B), width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'เปลี่ยน',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาร้านหรือเมนู',
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => RestaurantSearchScreen(
                                merchants: widget.merchants,
                                initialKeyword: _searchController.text,
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.topBar,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('ตัวกรอง', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EAEF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EAEF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE3001B), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PromoBanner(
                  onTap: () {
                    showDemoInfoSheet(
                      context,
                      title: 'โปรพิเศษประจำวัน',
                      paragraphs: const <String>[
                        'ส่วนลดและคูปองตามร้านที่ร่วมรายการ — แตะการ์ดร้านด้านล่างแล้วดูแท็กโปรบนเมนู',
                        'ยอดขั้นต่ำและเงื่อนไขค่าส่งแสดงก่อนชำระเงิน',
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ร้านแนะนำ',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => RestaurantSearchScreen(
                              merchants: widget.merchants,
                              initialKeyword: _searchController.text,
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE3001B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'ตัวกรอง',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...filteredMerchants.map(
                  (merchant) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _RestaurantBrowseCard(
                      merchant: merchant,
                      onTap: () => _openMerchant(merchant),
                    ),
                  ),
                ),
                if (filteredMerchants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'ไม่พบร้านที่ตรงกับการค้นหา',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _DeliveryPickupBar(
            mode: _deliveryMode,
            onChanged: (v) => setState(() => _deliveryMode = v),
          ),
        ],
      ),
    );
  }
}

class RestaurantSearchScreen extends StatefulWidget {
  const RestaurantSearchScreen({
    super.key,
    required this.merchants,
    this.initialKeyword = '',
  });

  final List<RegisteredMerchant> merchants;
  final String initialKeyword;

  @override
  State<RestaurantSearchScreen> createState() => _RestaurantSearchScreenState();
}

class _RestaurantSearchScreenState extends State<RestaurantSearchScreen> {
  late final TextEditingController _searchController =
      TextEditingController(text: widget.initialKeyword);
  String _selectedCategory = 'ทั้งหมด';

  List<String> _categories() {
    final items = widget.merchants.map((e) => e.category).toSet().toList()..sort();
    return ['ทั้งหมด', ...items];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim().toLowerCase();
    final merchants = widget.merchants.where((merchant) {
      final byWord = keyword.isEmpty ||
          merchant.name.toLowerCase().contains(keyword) ||
          merchant.category.toLowerCase().contains(keyword);
      final byCategory =
          _selectedCategory == 'ทั้งหมด' || merchant.category == _selectedCategory;
      return byWord && byCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: kUnifiedTopBarBg,
        foregroundColor: kUnifiedTopBarFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kUnifiedTopBarToolbarHeight,
        title: const _AppBarTitleWithLogo(
          title: 'เลือกหมวดอาหาร',
          titleStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kUnifiedTopBarFg),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาเมนู',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories().map((category) {
                        final selected = category == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedCategory = category),
                            selectedColor: const Color(0xFFE3001B),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: merchants.length,
                itemBuilder: (context, index) {
                  final merchant = merchants[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RestaurantBrowseCard(
                      merchant: merchant,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => RestaurantDetailScreen(
                              merchant: merchant,
                              menuItems: AppConfig.useApi ? null : menuForMerchant(merchant),
                              pickupMode: false,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantMenuEntry {
  const _RestaurantMenuEntry.header(this.title) : itemIndex = null;
  const _RestaurantMenuEntry.item(this.itemIndex) : title = null;
  final String? title;
  final int? itemIndex;
  bool get isHeader => title != null;
}

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({
    super.key,
    required this.merchant,
    this.menuItems,
    this.pickupMode = false,
    this.reorderLines,
  });

  final RegisteredMerchant merchant;
  /// ถ้า null จะโหลดเมนูจาก [CatalogRepository] (โหมด API)
  final List<FoodMenuItem>? menuItems;
  final bool pickupMode;
  final List<OrderLine>? reorderLines;

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  static const Color _red = Color(0xFFE3001B);
  /// สีราคาให้อ่านง่ายบนพื้นขาว / เมื่อมี overlay เบา
  static const Color _priceText = Color(0xFFB80012);

  late List<FoodMenuItem> _items;
  late List<int> _qty;
  bool _loadingMenu = true;

  @override
  void initState() {
    super.initState();
    final pre = widget.menuItems;
    if (pre != null && pre.isNotEmpty) {
      _items = pre;
      _qty = List<int>.filled(_items.length, 0);
      _loadingMenu = false;
      _applyReorderLines();
    } else {
      _items = [];
      _qty = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMenuFromApi();
      });
    }
  }

  Future<void> _loadMenuFromApi() async {
    try {
      final slug = widget.merchant.slug.isEmpty ? widget.merchant.name : widget.merchant.slug;
      final list = await context.read<CatalogRepository>().fetchMenu(slug);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = list;
        _qty = List<int>.filled(_items.length, 0);
        _loadingMenu = false;
      });
      _applyReorderLines();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items = menuForMerchant(widget.merchant);
        _qty = List<int>.filled(_items.length, 0);
        _loadingMenu = false;
      });
      _applyReorderLines();
    }
  }

  void _applyReorderLines() {
    final List<OrderLine>? lines = widget.reorderLines;
    if (lines == null || lines.isEmpty) {
      return;
    }
    for (var i = 0; i < _items.length; i++) {
      final FoodMenuItem item = _items[i];
      for (final OrderLine line in lines) {
        if (line.itemName == item.name && line.unitPrice == item.price) {
          _qty[i] = line.qty.clamp(0, 99);
          break;
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ใส่รายการเคยสั่งลงตะกร้าแล้ว — แก้จำนวนได้ก่อนชำระ'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    });
  }

  List<_RestaurantMenuEntry> _menuEntriesForList() {
    if (_items.isEmpty) {
      return const [];
    }
    final useHeaders = _items.any((FoodMenuItem e) => e.section.trim().isNotEmpty);
    if (!useHeaders) {
      return List<_RestaurantMenuEntry>.generate(_items.length, (int i) => _RestaurantMenuEntry.item(i));
    }
    final List<int> idx = List<int>.generate(_items.length, (int i) => i);
    idx.sort((int a, int b) {
      final String ea = _items[a].section.trim();
      final String eb = _items[b].section.trim();
      final String ka = ea.isEmpty ? '\uFFFF' : ea;
      final String kb = eb.isEmpty ? '\uFFFF' : eb;
      final int c = ka.compareTo(kb);
      if (c != 0) {
        return c;
      }
      return _items[a].name.compareTo(_items[b].name);
    });
    String? prevKey;
    final List<_RestaurantMenuEntry> out = <_RestaurantMenuEntry>[];
    for (final int i in idx) {
      final String raw = _items[i].section.trim();
      final String key = raw.isEmpty ? '__empty__' : raw;
      if (key != prevKey) {
        out.add(_RestaurantMenuEntry.header(raw.isEmpty ? 'ไม่ระบุหมวด' : raw));
        prevKey = key;
      }
      out.add(_RestaurantMenuEntry.item(i));
    }
    return out;
  }

  int get _cartPieces => _qty.fold(0, (a, b) => a + b);

  int get _cartTotalBaht {
    var sum = 0;
    for (var i = 0; i < _items.length; i++) {
      sum += _items[i].price * _qty[i];
    }
    return sum;
  }

  void _setQty(int index, int value) {
    final next = value.clamp(0, 99);
    if (_qty[index] == next) {
      return;
    }
    setState(() => _qty[index] = next);
  }

  Future<void> _onCartBarTap() async {
    if (_cartTotalBaht <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกจำนวนเมนูก่อน'),
          backgroundColor: Color(0xFFE3001B),
        ),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (context) => _DeliveryTimeSheet(
        merchant: widget.merchant,
        pickupMode: widget.pickupMode,
      ),
    );
    if (!mounted || ok != true) {
      return;
    }
    final breakdown = estimateDeliveryPhases(widget.merchant, pickupMode: widget.pickupMode);
    final List<OrderLine> lines = <OrderLine>[];
    for (var i = 0; i < _items.length; i++) {
      if (_qty[i] <= 0) {
        continue;
      }
      lines.add(
        OrderLine(
          itemName: _items[i].name,
          unitPrice: _items[i].price,
          qty: _qty[i],
        ),
      );
    }
    final paid = await showPaymentCheckout(
      context,
      amountBaht: _cartTotalBaht,
      purpose: 'order',
    );
    if (paid == null || !paid.isSucceeded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังไม่ได้ชำระเงินสำเร็จ')),
        );
      }
      return;
    }
    final String tentativeId = 'ord-${DateTime.now().millisecondsSinceEpoch}';
    final String orderId = await OrderStore.addOrder(
      PlacedOrder(
        id: tentativeId,
        placedAt: DateTime.now(),
        merchant: widget.merchant,
        lines: lines,
        totalBaht: _cartTotalBaht,
        deliveryBreakdown: breakdown,
        pickupMode: widget.pickupMode,
        statusLabel: 'กำลังจัดส่ง',
        paymentIntentId: paid.id,
      ),
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => OrderTrackingScreen(
          merchant: widget.merchant,
          totalBaht: _cartTotalBaht,
          etaMinutes: breakdown.totalMinutes,
          pickupMode: widget.pickupMode,
          deliveryBreakdown: breakdown,
        ),
      ),
    );
    if (mounted) {
      await OrderStore.markCompleted(orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchant = widget.merchant;
    final items = _items;
    final List<_RestaurantMenuEntry> entries = _menuEntriesForList();
    final hasCart = !_loadingMenu && _cartTotalBaht > 0;

    if (_loadingMenu) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(merchant.name),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  merchant.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => Container(
                    color: const Color(0xFFECEEF2),
                    alignment: Alignment.center,
                    child: const Icon(Icons.restaurant, size: 56, color: Colors.black26),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 4,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    merchant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 20),
                    Text(
                      merchant.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'เมนูทั้งหมด (${items.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              physics: const BouncingScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (BuildContext context, int di) {
                final _RestaurantMenuEntry entry = entries[di];
                if (entry.isHeader) {
                  return Padding(
                    padding: EdgeInsets.only(top: di > 0 ? 12 : 0, bottom: 8),
                    child: Text(
                      entry.title!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  );
                }
                final int index = entry.itemIndex!;
                final FoodMenuItem item = items[index];
                final int q = _qty[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '฿${item.price}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _priceText,
                                  letterSpacing: 0.2,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border, width: 2),
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.surfaceElevated,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton(
                                onPressed: q > 0 ? () => _setQty(index, q - 1) : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  maximumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: q > 0 ? const Color(0xFF0D0D0D) : const Color(0xFF9E9E9E),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF9E9E9E),
                                  disabledForegroundColor: Color(0xFFE8E8E8),
                                  shape: const CircleBorder(),
                                  elevation: q > 0 ? 2 : 0,
                                  shadowColor: Colors.black54,
                                ),
                                child: const Icon(Icons.remove_rounded, size: 24),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '$q',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: () => _setQty(index, q + 1),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  maximumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: const Color(0xFFDA0018),
                                  foregroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 3,
                                  shadowColor: Colors.black45,
                                ),
                                child: const Icon(Icons.add_rounded, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 28, color: AppColors.border.withValues(alpha: 0.45)),
                  ],
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasCart
                ? Material(
                    key: const ValueKey('cart_on'),
                    color: AppColors.topBar,
                    elevation: 12,
                    shadowColor: Colors.black54,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _onCartBarTap,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                                          Positioned(
                                            right: -8,
                                            top: -8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: const BoxDecoration(
                                                color: _red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '$_cartPieces',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'ตะกร้า',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '$_cartPieces รายการ · แตะเลือกเวลาส่ง',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.92),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '฿$_cartTotalBaht',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _onCartBarTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDA0018),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Colors.black54,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'ชำระเงิน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Material(
                    key: const ValueKey('cart_off'),
                    color: const Color(0xFFECEEF2),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade600, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ตะกร้าว่าง — กด + เพื่อเพิ่มเมนู',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPhaseTile extends StatelessWidget {
  const _DeliveryPhaseTile({
    required this.phaseIndex,
    required this.title,
    required this.subtitle,
    required this.minutes,
  });

  final int phaseIndex;
  final String title;
  final String subtitle;
  final int minutes;

  static const Color _red = Color(0xFFDA0018);

  @override
  Widget build(BuildContext context) {
    final timeLabel = minutes <= 0 ? '—' : '$minutes น.';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D2D), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$phaseIndex',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeLabel,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: minutes <= 0 ? Colors.grey.shade600 : const Color(0xFFB80012),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTimeSheet extends StatelessWidget {
  const _DeliveryTimeSheet({
    required this.merchant,
    required this.pickupMode,
  });

  final RegisteredMerchant merchant;
  final bool pickupMode;

  @override
  Widget build(BuildContext context) {
    final bd = estimateDeliveryPhases(merchant, pickupMode: pickupMode);
    final title = pickupMode ? 'สรุปเวลารับที่ร้าน' : 'สรุปเวลาจัดส่ง';

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 8),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 1,
                      color: Color(0xFF000000),
                      height: 1.2,
                    ),
                  ),
                ),
                Text(
                  'รวมประมาณ ${bd.totalMinutes} นาที',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFFDA0018),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'คำนวณจากระยะ ~${bd.distanceKm.toStringAsFixed(1)} กม. และเวลาที่ร้านประเมิน ${merchant.etaMinutes} น.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Divider(height: 20, thickness: 1, color: Colors.grey.shade400),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      _DeliveryPhaseTile(
                        phaseIndex: 1,
                        title: bd.phase1Title,
                        subtitle: bd.phase1Subtitle,
                        minutes: bd.phase1Minutes,
                      ),
                      _DeliveryPhaseTile(
                        phaseIndex: 2,
                        title: bd.phase2Title,
                        subtitle: bd.phase2Subtitle,
                        minutes: bd.phase2Minutes,
                      ),
                      _DeliveryPhaseTile(
                        phaseIndex: 3,
                        title: bd.phase3Title,
                        subtitle: bd.phase3Subtitle,
                        minutes: bd.phase3Minutes,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF000000),
                              backgroundColor: const Color(0xFFF7F7F7),
                              side: const BorderSide(color: Color(0xFF000000), width: 2.5),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF000000),
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDA0018),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFBDBDBD),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 6,
                              shadowColor: Colors.black54,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'ยืนยันคำสั่งซื้อ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.2,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({
    super.key,
    required this.merchant,
    required this.totalBaht,
    required this.etaMinutes,
    this.pickupMode = false,
    required this.deliveryBreakdown,
  });

  final RegisteredMerchant merchant;
  final int totalBaht;
  final int etaMinutes;
  final bool pickupMode;
  final DeliveryPhaseBreakdown deliveryBreakdown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8EAEF),
                  Color(0xFFD4D8E0),
                  Color(0xFFC5CAD4),
                ],
              ),
            ),
            child: CustomPaint(
              painter: _MapRoutePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 8,
            child: CircleAvatar(
              backgroundColor: AppColors.surface,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.34,
            left: MediaQuery.sizeOf(context).width * 0.22,
            child: _MapPin(color: Colors.red.shade700, icon: Icons.restaurant_rounded),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.52,
            right: MediaQuery.sizeOf(context).width * 0.2,
            child: const _MapPin(color: Color(0xFFE3001B), icon: Icons.person_pin_circle_rounded),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: AppColors.surfaceElevated,
              elevation: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$etaMinutes นาที',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pickupMode
                            ? 'รอรับออเดอร์ที่ร้าน — พร้อมแล้วจะแจ้งให้ทราบ'
                            : 'รับออเดอร์ของคุณแล้ว — กำลังจัดเตรียมอาหาร',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เวลาแบ่ง 3 เฟส',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '① ${deliveryBreakdown.phase1Title} · ${deliveryBreakdown.phase1Minutes} น.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              '② ${deliveryBreakdown.phase2Title} · ${deliveryBreakdown.phase2Minutes} น.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              '③ ${deliveryBreakdown.phase3Title} · ${phase3TimeLabel(deliveryBreakdown)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ยอดรวม',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '฿$totalBaht',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE3001B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: 0.35,
                          backgroundColor: AppColors.border,
                          color: const Color(0xFFE3001B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE3001B).withValues(alpha: 0.55)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.36)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.42,
        size.width * 0.72,
        size.height * 0.54,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _foodItemImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (url.isEmpty) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFECEEF2),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.black26),
    );
  }
  if (url.startsWith('data:image')) {
    try {
      final int comma = url.indexOf(',');
      if (comma < 0) {
        throw const FormatException('bad data url');
      }
      final bytes = base64Decode(url.substring(comma + 1));
      return Image.memory(bytes, fit: fit, width: width, height: height, gaplessPlayback: true);
    } catch (_) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFECEEF2),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black26),
      );
    }
  }
  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, _, _) => Container(
      width: width,
      height: height,
      color: const Color(0xFFECEEF2),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: Colors.black26),
    ),
  );
}

class MenuItemDetailScreen extends StatefulWidget {
  const MenuItemDetailScreen({
    super.key,
    required this.merchant,
    required this.item,
  });

  final RegisteredMerchant merchant;
  final FoodMenuItem item;

  @override
  State<MenuItemDetailScreen> createState() => _MenuItemDetailScreenState();
}

class _MenuItemDetailScreenState extends State<MenuItemDetailScreen> {
  String _spiceLevel = 'เผ็ดกลาง';
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final total = widget.item.price * _qty;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: kUnifiedTopBarBg,
        foregroundColor: kUnifiedTopBarFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kUnifiedTopBarToolbarHeight,
        title: const _AppBarTitleWithLogo(
          title: 'เลือกเมนู',
          titleStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: kUnifiedTopBarFg,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _foodItemImage(widget.item.imageUrl, fit: BoxFit.cover),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.description,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '฿${widget.item.price}',
                    style: const TextStyle(
                      color: Color(0xFFE3001B),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ตัวเลือก',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['เผ็ดน้อย', 'เผ็ดกลาง', 'เผ็ดมาก']
                        .map(
                          (level) => ChoiceChip(
                            label: Text(level),
                            selected: _spiceLevel == level,
                            onSelected: (_) => setState(() => _spiceLevel = level),
                            selectedColor: const Color(0xFFE3001B),
                            labelStyle: TextStyle(
                              color: _spiceLevel == level ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'หมายเหตุถึงร้านค้า',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'เช่น ไม่ใส่ผักชี',
                      fillColor: AppColors.surfaceElevated,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text(
                          '$_qty',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _qty++),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE3001B),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'เพิ่ม ${widget.item.name} จาก ${widget.merchant.name} ลงตะกร้าแล้ว ฿$total',
                            ),
                          ),
                        );
                      },
                      child: Text('เพิ่มไปยังตะกร้า ฿$total'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// รากแอป: โหลด [SharedPreferences], ผูก Provider, ล็อกอินเมื่อ `USE_API=true`
class InfinityProductionBootstrap extends StatelessWidget {
  const InfinityProductionBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.mainDark(),
            home: ColoredBox(
              color: AppColors.canvas,
              child: Center(
                child: Text(UiStringsTh.appName, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }
        final prefs = snap.data!;
        final session = AuthSession(prefs);
        final client = InfinityApiClient(tokenGetter: () async => session.tokenOrNull);
        JobStore.instance.attachClient(client);
        return MultiProvider(
          providers: [
            Provider<AuthSession>.value(value: session),
            Provider<InfinityApiClient>.value(value: client),
            Provider(create: (_) => AuthRepository(client, session)),
            Provider(create: (_) => CatalogRepository(client)),
            Provider(create: (_) => OrderRepository(client)),
            Provider(create: (_) => AddressRepository(client)),
            Provider(create: (_) => WalletRepository(client)),
            Provider(create: (_) => PaymentRepository(client)),
            Provider(create: (_) => MapsRepository(client)),
            Provider(create: (_) => PushRegistrationRepository(client)),
            Provider(create: (_) => AdminRepository(client)),
            Provider(create: (_) => MerchantRepository(client)),
            Provider(create: (_) => BookingRepository(client)),
            ChangeNotifierProvider<ProfileStore>(create: (_) => ProfileStore(prefs)),
            ChangeNotifierProvider<NotificationStore>(create: (_) => NotificationStore(client)),
            ChangeNotifierProvider<SavedPlacesStore>(create: (_) => SavedPlacesStore(client)),
          ],
          child: Builder(
            builder: (BuildContext c) {
              AppScope.orderRepository = c.read<OrderRepository>();
              OrderStoreBridge.localOrders = OrderStore.ordersForDisplay;
              return const AuthRoot();
            },
          ),
        );
      },
    );
  }
}

/// ให้ลูกหลานเรียก [logout] เพื่อล้างโทเคนและให้ [AuthRoot] กลับไปหน้าล็อกอิน
class AppLogoutScope extends InheritedWidget {
  const AppLogoutScope({super.key, required this.logout, required super.child});

  final Future<void> Function() logout;

  static Future<void>? logoutIfPresent(BuildContext context) {
    final scope = context.findAncestorWidgetOfExactType<AppLogoutScope>();
    return scope?.logout();
  }

  /// มีขอบเขตล็อกอิน API (ลูกหลานของ [AppLogoutScope])
  static bool isInSession(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AppLogoutScope>() != null;
  }

  /// ล็อกเอาต์แล้วกลับหน้าเข้าสู่ระบบ
  static Future<void> logoutOrDemoExit(BuildContext context) async {
    final scope = context.findAncestorWidgetOfExactType<AppLogoutScope>();
    if (scope != null) {
      await scope.logout();
    }
  }

  @override
  bool updateShouldNotify(covariant AppLogoutScope oldWidget) => logout != oldWidget.logout;
}

class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key});

  @override
  State<AuthRoot> createState() => _AuthRootState();
}

class _AuthRootState extends State<AuthRoot> {
  bool _loading = true;
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final pending = _oauthToken;
    if (pending != null && pending.isNotEmpty) {
      _oauthToken = null;
      await context.read<AuthSession>().setToken(pending);
      if (!mounted) return;
    }
    final u = await context.read<AuthRepository>().fetchMe();
    if (!mounted) {
      return;
    }
    setState(() {
      _user = u;
      _loading = false;
    });
    if (u != null) {
      await _syncStores();
    }
  }

  void _onLoggedIn(AuthUser u) {
    setState(() => _user = u);
    _syncStores();
  }

  Future<void> _syncStores() async {
    try {
      await context.read<NotificationStore>().refresh();
      await context.read<SavedPlacesStore>().refresh();
      await JobStore.instance.refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.mainDark(),
        home: ColoredBox(
          color: AppColors.canvas,
          child: Center(
            child: Text('กำลังโหลด…', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }
    if (_user == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.mainDark(),
        home: LoginScreen(onLoggedIn: _onLoggedIn, initialError: _oauthError),
      );
    }
    return AppLogoutScope(
      logout: () async {
        await context.read<AuthRepository>().logout();
        if (mounted) {
          setState(() => _user = null);
        }
      },
      child: const InfinityApp(home: HomeScreen()),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFFE3001B)],
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.card_giftcard, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'สั่งอาหารให้ส่งถึงที่วันนี้',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'รับเลย',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
