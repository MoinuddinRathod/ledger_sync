import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rive/rive.dart';

import '../controllers/bear_controller.dart';

class BearAnimationWidget extends GetView<BearController> {
  final double height;
  final double width;

  const BearAnimationWidget({super.key, this.height = 220, this.width = 280});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        height: height,
        width: width,
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
          child: Obx(() {
            if (!controller.isLoaded.value ||
                controller.riveController == null) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            return RiveWidget(
              controller: controller.riveController!,
              fit: Fit.contain,
            );
          }),
        ),
      ),
    );
  }
}
