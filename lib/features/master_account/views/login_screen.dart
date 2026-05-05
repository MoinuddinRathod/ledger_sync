import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rive/rive.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/custome_labeled_field.dart';
import '../controllers/master_account_controller.dart';

// ─────────────────────────────────────────────
// BEAR STATE ENUM
// Only one state is active at a time.
// ─────────────────────────────────────────────
enum BearState { idle, speaking, checking, handsUp }

// ─────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────
class LoginScreen extends GetView<MasterAccountController> {
  const LoginScreen({super.key});

  static final _bearKey = GlobalKey<BearAnimationWidgetState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Wire callbacks every build (safe — they're just assignments)
    controller.onLoginSuccess = (Future<void> Function() onComplete) {
      _bearKey.currentState?.fireSuccess(onComplete);
    };
    controller.onLoginFail = () {
      _bearKey.currentState?.fireFail();
    };

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

                // Bear is NOT in Obx — state is driven imperatively via the key
                BearAnimationWidget(key: _bearKey),

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
                            _bearKey.currentState?.setBearState(
                              hasFocus ? BearState.handsUp : BearState.idle,
                            );
                          },
                          onChanged: (val) {
                            if (val.isNotEmpty) {
                              _bearKey.currentState?.setBearState(
                                controller.isPinVisible.value
                                    ? BearState.checking
                                    : BearState.handsUp,
                              );
                              controller.startTypingTimer(() {
                                _bearKey.currentState?.setBearState(
                                  BearState.idle,
                                );
                              });
                            }
                          },
                          onObscureTap: () {
                            controller.togglePinVisibility();
                            _bearKey.currentState?.setBearState(
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

// ─────────────────────────────────────────────
// BEAR ANIMATION WIDGET
// Uses the modern rive 0.14 API:
//   File.asset() → RiveWidgetController → dataBind(DataBind.auto())
//   → ViewModelInstance.boolean() / .trigger()
//
// The bear has ONE active state at a time (BearState enum).
// State is driven imperatively via the GlobalKey from the parent screen.
// ─────────────────────────────────────────────
class BearAnimationWidget extends StatefulWidget {
  final double height;
  final double width;

  const BearAnimationWidget({super.key, this.height = 220, this.width = 280});

  @override
  State<BearAnimationWidget> createState() => BearAnimationWidgetState();
}

class BearAnimationWidgetState extends State<BearAnimationWidget> {
  late final FileLoader _fileLoader;
  RiveWidgetController? _riveController;
  StateMachine? _stateMachine;
  bool _loaded = false;
  BearState _bearState = BearState.idle;

  @override
  void initState() {
    super.initState();
    _fileLoader = FileLoader.fromAsset(
      'assets/animations/9940-18945-speaking-bear.riv',
      riveFactory: Factory.rive,
    );
    _loadRive();
  }

  Future<void> _loadRive() async {
    final file = await File.asset(
      'assets/animations/9940-18945-speaking-bear.riv',
      riveFactory: Factory.rive,
    );

    if (file == null || !mounted) return;

    final riveController = RiveWidgetController(file);

    // Direct StateMachine access — no dataBind needed
    final sm = riveController.stateMachine;

    debugPrint('=== Bear inputs ===');
    for (final input in sm?.inputs ?? []) {
      debugPrint('  name: "${input.name}"  type: ${input.runtimeType}');
    }

    setState(() {
      _riveController = riveController;
      _stateMachine = sm;
      _loaded = true;
    });

    _applyBearState();
  }

  void _applyBearState() {
    final sm = _stateMachine;
    if (sm == null) return;

    sm.boolean('Speaking')?.value = _bearState == BearState.speaking;
    sm.boolean('Check')?.value = _bearState == BearState.checking;
    sm.boolean('hands_up')?.value = _bearState == BearState.handsUp;
  }

  void setBearState(BearState newState) {
    if (_bearState == newState) return;
    setState(() {
      _bearState = newState;
    });
    _applyBearState();
  }

  void fireFail() {
    _stateMachine?.trigger('fail')?.fire();
  }

  void fireSuccess(VoidCallback onComplete) {
    _stateMachine?.trigger('success')?.fire();
    Future.delayed(const Duration(milliseconds: 2500), onComplete);
  }

  @override
  void dispose() {
    _riveController?.dispose();
    _fileLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2040) : const Color(0xFFF0F2FF),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: _loaded && _riveController != null
              ? RiveWidget(controller: _riveController!, fit: Fit.contain)
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
