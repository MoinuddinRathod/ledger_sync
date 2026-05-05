import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SnackbarService {
  static void _showModernSnackbar({
    required String title,
    required String message,
    required Color baseColor,
    required IconData icon,
  }) {
    Get.rawSnackbar(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderRadius: 12,
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),

      animationDuration: const Duration(milliseconds: 400),
      boxShadows: [
        BoxShadow(
          color: baseColor.withValues(alpha: 0.25),
          offset: const Offset(0, 10),
          blurRadius: 30,
        ),
      ],

      // Instead of an actual border, we simulate the bottom colored bar
      // using a pseudo-widget injected via the background or custom layout if possible.
      // But standard GetX snackbar can take a custom message or title widget.
      // To strictly match the design (having a bottom border decorator), we can use `borderColor` but it goes all around.
      // Easiest is to use the `barBlur` with custom border on the container, but since Get.rawSnackbar restricts decorators slightly,
      // we can inject a Custom widget into the `messageText` property that defines the layout.
      messageText: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(Get.context!).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(
                          Get.context!,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // We override the title to null since we build the entire layout in messageText
      titleText: const SizedBox.shrink(),
      icon: const SizedBox.shrink(),
      shouldIconPulse: false,
    );
  }

  static void showSuccess({
    String title = 'Successful toast',
    String message = "It's a green notification state",
  }) {
    _showModernSnackbar(
      title: title,
      message: message,
      baseColor: const Color(0xFF4ADE80), // Green shade matching UI
      icon: Icons.check,
    );
  }

  static void showWarning({
    String title = 'Warning toast',
    String message = "It's a orange notification state",
  }) {
    _showModernSnackbar(
      title: title,
      message: message,
      baseColor: const Color(0xFFFBBF24), // Orange shade matching UI
      icon: Icons.warning_amber_rounded,
    );
  }

  static void showInfo({
    String title = 'Neutral toast',
    String message = "It's a default notification state",
  }) {
    _showModernSnackbar(
      title: title,
      message: message,
      baseColor: Theme.of(
        Get.context!,
      ).colorScheme.onSurface.withValues(alpha: 0.5),
      icon: Icons.info_outline,
    );
  }

  static void showNotification({
    String title = "Notifications UI design",
    String message = "Read full tutorial to enhance skills",
  }) {
    _showModernSnackbar(
      title: title,
      message: message,
      baseColor: Theme.of(Get.context!).colorScheme.primary,
      icon: Icons.notifications_none,
    );
  }

  static void showError({
    String title = 'Error toast',
    String message = "It's a red notification state",
  }) {
    _showModernSnackbar(
      title: title,
      message: message,
      baseColor: Theme.of(Get.context!).colorScheme.error,
      icon: Icons.block,
    );
  }
}
