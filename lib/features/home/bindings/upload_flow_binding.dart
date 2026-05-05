import 'package:get/get.dart';
import '../controllers/upload_file_controller.dart';

class UploadFlowBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UploadFileController>(
      () => UploadFileController(),
      fenix: true,
    );
  }
}
