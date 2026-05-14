import '../config/app_config.dart';
import '../data/orders/order_repository.dart';
import '../domain/food_ordering.dart';

/// ค่าแชร์ระหว่าง OrderStore กับ repository (หลีกเลี่ยง circular import กับ main)
class AppScope {
  AppScope._();

  static OrderRepository? orderRepository;
  static List<RegisteredMerchant> merchantsForOrders = kSeedMerchants;

  static bool get ordersRemote => AppConfig.useApi && orderRepository != null;
}
