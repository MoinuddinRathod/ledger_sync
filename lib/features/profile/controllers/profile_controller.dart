import 'package:get/get.dart';
import '../../../core/service/dialog_service.dart';
import '../../master_account/controllers/master_account_controller.dart';

class ProfileController extends GetxController {
  void logout() async {
    final bool? confirmLogout = await DialogService.showWarningDialog(
      title: "Logout",
      description: "Are you sure you want to log out of your account?",
      onConfirm: () {
        Get.back(result: true);
      },
    );

    if (confirmLogout == true) {
      if (Get.isRegistered<MasterAccountController>()) {
        Get.find<MasterAccountController>().logout();
      } else {
        final ctr = Get.put(MasterAccountController());
        ctr.logout();
      }
    }
  }
}
