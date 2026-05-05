import 'package:get/get.dart';

import '../controller/virtual_entries_controller.dart';

class VirtualEntriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VirtualEntriesController>(
      () => VirtualEntriesController(),
      fenix: true,
    );
  }
}
