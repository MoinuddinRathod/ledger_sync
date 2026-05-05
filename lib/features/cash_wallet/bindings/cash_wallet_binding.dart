import 'package:get/get.dart';
import '../controller/cash_wallet_controller.dart';

class CashWalletBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CashWalletController());
  }
}
