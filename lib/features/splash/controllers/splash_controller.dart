import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/cash_tag_service.dart';
import '../../master_account/controllers/master_account_controller.dart';

class SplashController extends GetxController {
  final LocalStorageService _localStorage = LocalStorageService.instance;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Initialize CashTagService (Feature A)
    if (!Get.isRegistered<CashTagService>()) {
      await Get.putAsync<CashTagService>(() async {
        final service = CashTagService();
        await service.initialize();
        return service;
      }, permanent: true);
    }

    // Ensure MasterAccountController is available
    final masterController = Get.isRegistered<MasterAccountController>()
        ? Get.find<MasterAccountController>()
        : Get.put(MasterAccountController());

    // Check if user has completed onboarding
    final hasOnboarded = _localStorage.hasCompletedOnboarding;

    if (!hasOnboarded) {
      // First-time user: Show Get Started screen
      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAllNamed('/get-started');
      return;
    }

    // Returning user: Check session and navigate accordingly
    await Future.delayed(const Duration(milliseconds: 300));
    masterController.checkSession();
  }
}
