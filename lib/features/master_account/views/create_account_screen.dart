import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/custome_labeled_field.dart';
import '../controllers/bear_controller.dart';
import '../controllers/master_account_controller.dart';
import '../widgets/bear_animation_widget.dart';

class CreateAccountScreen extends GetView<MasterAccountController> {
  CreateAccountScreen({super.key});
  final bearCtr = Get.find<BearController>();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bear — NOT inside Obx, driven via GlobalKey
                Center(child: BearAnimationWidget(height: 180, width: 220)),
                const SizedBox(height: 12),

                Text(
                  "Create Master Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Set up your local profile to start tracking.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // Form Card
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
                      // ── Account Name ── bear looks down (isChecking)
                      CustomLabeledTextField(
                        controller: controller.accountNameController,
                        label: "Account Name",
                        hintText: "Enter a name for this account",
                        prefixIcon: Icons.person_outline_rounded,
                        onFocusChange: (hasFocus) {
                          bearCtr.setBearState(
                            hasFocus ? BearState.checking : BearState.idle,
                          );
                        },
                        onChanged: (val) {
                          if (val.isNotEmpty) {
                            bearCtr.setBearState(BearState.speaking);
                            controller.startTypingTimer(() {
                              bearCtr.setBearState(BearState.idle);
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please enter an account name";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── PIN ── bear puts hands up (isHandsUp)
                      Obx(
                        () => CustomLabeledTextField(
                          controller: controller.pinController,
                          label: "Secure PIN",
                          hintText: "Enter a 6-digit PIN",
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your PIN";
                            }
                            if (value.length < 6) {
                              return "PIN must be at least 6 digits";
                            }
                            return null;
                          },
                          onObscureTap: () {
                            controller.isPinVisible.value =
                                !controller.isPinVisible.value;
                            bearCtr.setBearState(
                              controller.isPinVisible.value
                                  ? BearState.checking
                                  : BearState.handsUp,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Confirm PIN ── bear puts hands up (isHandsUp)
                      Obx(
                        () => CustomLabeledTextField(
                          controller: controller.confirmPinController,
                          label: "Confirm PIN",
                          hintText: "Re-enter your 6-digit PIN",
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          isObscure: !controller.isConfirmPinVisible.value,
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
                                controller.isConfirmPinVisible.value
                                    ? BearState.checking
                                    : BearState.handsUp,
                              );
                              controller.startTypingTimer(() {
                                bearCtr.setBearState(BearState.idle);
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please confirm your PIN";
                            }
                            if (value != controller.pinController.text) {
                              return "PINs do not match";
                            }
                            return null;
                          },
                          onObscureTap: () {
                            controller.isConfirmPinVisible.value =
                                !controller.isConfirmPinVisible.value;
                            bearCtr.setBearState(
                              controller.isConfirmPinVisible.value
                                  ? BearState.checking
                                  : BearState.handsUp,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      Obx(
                        () => Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          child: CheckboxListTile(
                            title: Text(
                              "I agree to the terms and privacy policy",
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            activeColor: theme.colorScheme.primary,
                            value: controller.isAcceptedTerms.value,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              controller.isAcceptedTerms.value = value!;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Obx(
                        () => AppButton(
                          title: 'Create Account',
                          isLoading: controller.isLoading.value,
                          onTap: () {
                            controller.createAccount();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
