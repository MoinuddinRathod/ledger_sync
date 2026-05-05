import 'package:get/get.dart';

import '../../bank_account/controllers/bank_account_controller.dart';
import '../../cash_wallet/controller/cash_wallet_controller.dart';
import '../../tags/controllers/tags_controller.dart';
import '../../transactions/controller/all_transaction_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HomeController(), fenix: true);
    Get.lazyPut(() => DashboardController(), fenix: true);
    Get.lazyPut(() => TagsController(), fenix: true);
    Get.lazyPut(() => AllTransactionsController(), fenix: true);
    Get.lazyPut(() => BankAccountController(), fenix: true);
    Get.lazyPut(() => CashWalletController(), fenix: true);
  }
}
