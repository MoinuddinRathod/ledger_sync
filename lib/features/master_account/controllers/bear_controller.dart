import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rive/rive.dart';

// ─────────────────────────────────────────────
// BEAR STATE ENUM
// Only one state is active at a time.
// ─────────────────────────────────────────────
enum BearState { idle, speaking, checking, handsUp }

class BearController extends GetxController {
  final RxBool isLoaded = false.obs;

  RiveWidgetController? riveController;
  StateMachine? stateMachine;

  final Rx<BearState> bearState = BearState.idle.obs;

  @override
  void onInit() {
    super.onInit();
    loadRive();
  }

  Future<void> loadRive() async {
    final file = await File.asset(
      'assets/animations/9940-18945-speaking-bear.riv',
      riveFactory: Factory.rive,
    );

    if (file == null) return;

    riveController = RiveWidgetController(file);
    stateMachine = riveController!.stateMachine;

    _applyState();

    isLoaded.value = true;
  }

  void _applyState() {
    final sm = stateMachine;
    if (sm == null) return;

    sm.boolean('Speaking')?.value = bearState.value == BearState.speaking;
    sm.boolean('Check')?.value = bearState.value == BearState.checking;
    sm.boolean('hands_up')?.value = bearState.value == BearState.handsUp;
  }

  void setBearState(BearState newState) {
    if (bearState.value == newState) return;
    bearState.value = newState;
    _applyState();
  }

  void fireFail() {
    stateMachine?.trigger('fail')?.fire();
  }

  void fireSuccess(VoidCallback onComplete) {
    stateMachine?.trigger('success')?.fire();
    Future.delayed(const Duration(milliseconds: 1000), onComplete);
  }
}
