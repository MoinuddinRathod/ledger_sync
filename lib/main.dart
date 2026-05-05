import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ledger_sync/routes/app_routes.dart';
import 'package:rive/rive.dart';
import 'core/bindings/initial_bindings.dart';
import 'core/controllers/theme_controller.dart';
import 'core/service/local_db_service/local_db_service.dart';
import 'core/theme/theme.dart';
import 'features/master_account/services/password_encryption_decryption_service.dart';

import 'core/service/encryption_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await RiveNative.init();
    await DatabaseHelper.instance.database;
    await GetStorage.init();
    await PasswordEncryptionDecryptionService.instance.init();
    await EncryptionService.instance.init();

    // Initialize theme controller before app starts
    Get.put(ThemeController(), permanent: true);

    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint("Failed to initialize app: $e\n$stackTrace");
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Critical initialization error. Please restart the app or reinstall it if the issue persists.\n\nError: $e",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeController = ThemeController.to;
      return GetMaterialApp(
        title: 'Ledger Sync',
        debugShowCheckedModeBanner: false,
        themeMode: themeController.themeMode,
        theme: lightMode,
        darkTheme: darkMode,
        initialBinding: InitialBinding(),
        getPages: AppRoutes.pages,
        initialRoute: AppRoutes.splashScreen,
      );
    });
  }
}
