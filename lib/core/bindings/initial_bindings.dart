import 'package:get/get.dart';
import 'package:ledger_sync/features/splash/controllers/splash_controller.dart';
import '../../features/bank_account/controllers/bank_account_controller.dart';
import '../../features/cash_wallet/controller/cash_wallet_controller.dart';
import '../../features/home/controllers/dashboard_controller.dart';
import '../../features/home/controllers/upload_file_controller.dart';
import '../../features/master_account/controllers/master_account_controller.dart';
import '../../features/navbar/controller/navbar_controller.dart';
import '../../features/profile/controllers/profile_controller.dart';
import '../../features/tags/controllers/tags_controller.dart';
import '../../features/transactions/controller/all_transaction_controller.dart';
import '../../features/transactions/controller/transaction_controller.dart';
import '../../features/virtual_entries/controller/virtual_entries_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SplashController());
    Get.lazyPut(() => ProfileController(), fenix: true);
    Get.lazyPut(() => UploadFileController(), fenix: true);
    Get.lazyPut(() => MasterAccountController(), fenix: true);
    Get.lazyPut(() => TagsController(), fenix: true);
    Get.lazyPut(() => NavbarController(), fenix: true);
    Get.lazyPut(() => BankAccountController(), fenix: true);
    Get.lazyPut(() => CashWalletController(), fenix: true);
    Get.lazyPut(() => VirtualEntriesController(), fenix: true);
    Get.lazyPut<AllTransactionsController>(() => AllTransactionsController(),
        fenix: true);
    Get.lazyPut(() => TransactionsController(), fenix: true);
    Get.lazyPut(() => DashboardController(), fenix: true);
  }
}
