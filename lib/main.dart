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
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  try {
    SentryWidgetsFlutterBinding.ensureInitialized();
    await RiveNative.init();
    await DatabaseHelper.instance.database;
    await GetStorage.init();
    await PasswordEncryptionDecryptionService.instance.init();
    await EncryptionService.instance.init();

    // Initialize theme controller before app starts
    Get.put(ThemeController(), permanent: true);

    await SentryFlutter.init((options) {
      options.dsn =
          'https://fe453fa495ca186b27799f4b6acab69f@o4511386738950144.ingest.us.sentry.io/4511386745700352';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 0.05;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 0.05;
    }, appRunner: () => runApp(SentryWidget(child: const MyApp())));
  } catch (e, stackTrace) {
    Sentry.captureException(e, stackTrace: stackTrace);
    debugPrint("Failed to initialize app: $e\n$stackTrace");
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://fe453fa495ca186b27799f4b6acab69f@o4511386738950144.ingest.us.sentry.io/4511386745700352';
        // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
        // We recommend adjusting this value in production.
        options.tracesSampleRate = 0.05;
        // The sampling rate for profiling is relative to tracesSampleRate
        // Setting to 1.0 will profile 100% of sampled transactions:
        options.profilesSampleRate = 0.05;
      },
      appRunner: () => runApp(
        SentryWidget(
          child: MaterialApp(
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
