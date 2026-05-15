import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DialogService {
  /// General reusable method for the modern dialog matching the UI specs
  static Future<bool?> _showModernDialog({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    String confirmText = 'Confirm',
    Color? confirmButtonColor,
    bool showCancel = true,
    VoidCallback? onConfirm,
  }) async {
    return await Get.dialog<bool>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(Get.context!).colorScheme.surface,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Close Icon
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Get.back(result: false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        Get.context!,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(
                        Get.context!,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Status Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(Get.context!).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    Get.context!,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showCancel) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Get.back(result: false),
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(
                            Get.context!,
                          ).colorScheme.onSurface.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(Get.context!).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            confirmButtonColor ??
                            Theme.of(Get.context!).colorScheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // Specific implementation methods

  static Future<bool?> showDeleteDialog({required void Function() onConfirm}) {
    return _showModernDialog(
      icon: Icons.delete_outline,
      iconColor: Theme.of(Get.context!).colorScheme.error,
      iconBgColor: Theme.of(
        Get.context!,
      ).colorScheme.error.withValues(alpha: 0.1),
      title: 'Delete',
      description: 'Are you sure you want to delete?',
      confirmText: 'Confirm',
      confirmButtonColor: Theme.of(Get.context!).colorScheme.error,
      onConfirm: onConfirm,
    );
  }

  static Future<bool?> showWarningDialog({
    String title = 'Warning',
    String description = 'Are you sure about this action?',
    void Function()? onConfirm,
    bool showCancel = true,
    String confirmText = 'Confirm',
  }) {
    const warningColor = Color(0xFFFBBF24);
    return _showModernDialog(
      icon: Icons.error_outline,
      iconColor: warningColor,
      iconBgColor: warningColor.withValues(alpha: 0.1),
      title: title,
      description: description,
      confirmText: confirmText,
      confirmButtonColor: warningColor,
      showCancel: showCancel,
      onConfirm: onConfirm ?? () => Get.back(result: true),
    );
  }

  static Future<bool?> showConfirmDialog({
    String title = 'Confirm',
    String description = 'Are you sure you want to proceed?',
    String confirmText = 'Confirm',
    void Function()? onConfirm,
  }) {
    return _showModernDialog(
      icon: Icons.help_outline,
      iconColor: Theme.of(Get.context!).colorScheme.primary,
      iconBgColor: Theme.of(
        Get.context!,
      ).colorScheme.primary.withValues(alpha: 0.1),
      title: title,
      description: description,
      confirmText: confirmText,
      onConfirm: onConfirm ?? () => Get.back(result: true),
    );
  }

  static Future<bool?> showSuccessDialog({
    String title = 'Success',
    String description = 'Action is done successfully!',
    void Function()? onConfirm,
    String confirmText = 'Confirm',
  }) {
    const successColor = Color(0xFF4ADE80);
    return _showModernDialog(
      icon: Icons.check_circle_outline,
      iconColor: successColor,
      iconBgColor: successColor.withValues(alpha: 0.1),
      title: title,
      description: description,
      showCancel: false,
      confirmText: confirmText,
      onConfirm: onConfirm,
      confirmButtonColor: successColor,
    );
  }

  static Future<bool?> showActivationDialog({
    required String bankName,
    void Function()? onConfirm,
  }) {
    return _showModernDialog(
      icon: Icons.power_settings_new_rounded,
      iconColor: Theme.of(Get.context!).colorScheme.primary,
      iconBgColor: Theme.of(
        Get.context!,
      ).colorScheme.primary.withValues(alpha: 0.1),
      title: 'Activate Account',
      description:
          'This $bankName account is currently inactive. Would you like to activate it now to proceed with the import?',
      confirmText: 'Activate',
      onConfirm: onConfirm ?? () => Get.back(result: true),
    );
  }
}
