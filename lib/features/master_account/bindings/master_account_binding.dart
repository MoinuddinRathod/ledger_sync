import 'package:get/get.dart';
import '../controllers/master_account_controller.dart';

class MasterAccountBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MasterAccountController());
  }
}
