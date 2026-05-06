import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/custome_labeled_field.dart';
import '../controllers/bear_controller.dart';
import '../controllers/master_account_controller.dart';
import '../widgets/bear_animation_widget.dart';

// ─────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────
class LoginScreen extends GetView<MasterAccountController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bearCtr = Get.find<BearController>();
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const BearAnimationWidget(),

                const SizedBox(height: 16),

                Text(
                  "Welcome Back",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Log in to continue managing your finances.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Form Card ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1C35) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A2D52)
                          : const Color(0xFFE4E6FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.04,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "Log in as ${controller.accountNameController.text}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // PIN field — bear puts hands up when focused
                      Obx(
                        () => CustomLabeledTextField(
                          controller: controller.pinController,
                          label: "Secure PIN",
                          hintText: "Enter your 6-digit PIN",
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          isObscure: !controller.isPinVisible.value,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onFocusChange: (hasFocus) {
                            bearCtr.setBearState(
                              hasFocus ? BearState.handsUp : BearState.idle,
                            );
                          },
                          onChanged: (val) {
                            if (val.isNotEmpty) {
                              bearCtr.setBearState(
                                controller.isPinVisible.value
                                    ? BearState.checking
                                    : BearState.handsUp,
                              );
                              controller.startTypingTimer(() {
                                bearCtr.setBearState(BearState.idle);
                              });
                            }
                          },
                          onObscureTap: () {
                            controller.togglePinVisibility();
                            bearCtr.setBearState(
                              controller.isPinVisible.value
                                  ? BearState.checking
                                  : BearState.handsUp,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      Obx(
                        () => AppButton(
                          title: 'Login',
                          onTap: () => controller.login(),
                          isLoading: controller.isLoading.value,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Obx(
                  () => controller.accounts.isEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 15,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                controller.clearControllers();
                                Get.offNamed(
                                  AppRoutes.masterAccountSetupScreen,
                                );
                              },
                              child: Text(
                                "Create one",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
