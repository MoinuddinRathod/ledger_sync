import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Theme mode options
enum AppThemeMode { system, light, dark }

/// Controller for managing app theme
class ThemeController extends GetxController {
  static ThemeController get to => Get.find<ThemeController>();

  final _storage = GetStorage();
  static const String _themeKey = 'app_theme_mode';

  // Reactive theme mode
  final Rx<AppThemeMode> _themeMode = AppThemeMode.system.obs;

  /// Get current theme mode
  AppThemeMode get appThemeMode => _themeMode.value;

  /// Get ThemeMode for GetMaterialApp
  ThemeMode get themeMode {
    switch (_themeMode.value) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Check if dark mode is currently active
  bool get isDarkMode {
    if (_themeMode.value == AppThemeMode.dark) return true;
    if (_themeMode.value == AppThemeMode.light) return false;
    // For system mode, check platform brightness
    return Get.mediaQuery.platformBrightness == Brightness.dark;
  }

  /// Get theme mode display name
  String get themeModeName {
    switch (_themeMode.value) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromStorage();
  }

  /// Load saved theme from storage
  void _loadThemeFromStorage() {
    try {
      final savedTheme = _storage.read<String>(_themeKey);
      if (savedTheme != null) {
        _themeMode.value = AppThemeMode.values.firstWhere(
          (e) => e.name == savedTheme,
          orElse: () => AppThemeMode.system,
        );
      }
    } catch (e) {
      // If there's an error reading, default to system
      _themeMode.value = AppThemeMode.system;
    }
  }

  /// Save theme to storage
  Future<void> _saveThemeToStorage(AppThemeMode mode) async {
    try {
      await _storage.write(_themeKey, mode.name);
    } catch (e) {
      // Handle storage error silently
      debugPrint('Error saving theme: $e');
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode.value == mode) return;

    _themeMode.value = mode;
    await _saveThemeToStorage(mode);
  }

  /// Toggle between light and dark (for simple switch)
  Future<void> toggleTheme() async {
    final newMode = isDarkMode ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Show theme selection dialog
  void showThemeSelector() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose Theme',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Get.theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              title: 'System',
              subtitle: 'Follow device settings',
              icon: Icons.brightness_auto,
              isSelected: _themeMode.value == AppThemeMode.system,
              onTap: () {
                setThemeMode(AppThemeMode.system);
                Get.back();
              },
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              title: 'Light',
              subtitle: 'Always use light mode',
              icon: Icons.brightness_7,
              isSelected: _themeMode.value == AppThemeMode.light,
              onTap: () {
                setThemeMode(AppThemeMode.light);
                Get.back();
              },
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              title: 'Dark',
              subtitle: 'Always use dark mode',
              icon: Icons.brightness_2,
              isSelected: _themeMode.value == AppThemeMode.dark,
              onTap: () {
                setThemeMode(AppThemeMode.dark);
                Get.back();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Get.theme.colorScheme.primary.withValues(alpha: 0.1)
              : Get.theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Get.theme.colorScheme.primary
                : Get.theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Get.theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Get.theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Get.theme.colorScheme.primary
                    : Get.theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Get.theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Get.theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Get.theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
