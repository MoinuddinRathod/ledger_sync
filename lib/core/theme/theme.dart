import 'package:flutter/material.dart';

import 'app_colors.dart';

// for light mode
ThemeData lightMode = ThemeData(
  appBarTheme: AppBarTheme(scrolledUnderElevation: 0.0),
  textTheme: ThemeData.light().textTheme,
  actionIconTheme: ActionIconThemeData(
    backButtonIconBuilder: (context) =>
        Icon(Icons.arrow_back_ios, size: 22, color: AppColorsLight.onSurface),
  ),
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: AppColorsLight.primary,
    onPrimary: AppColorsLight.onPrimary,
    secondary: AppColorsLight.secondary,
    onSecondary: AppColorsLight.onSecondary,
    error: AppColorsLight.error,
    onError: AppColorsLight.onError,
    surface: AppColorsLight.surface,
    onSurface: AppColorsLight.onSurface,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColorsLight.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 4,
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColorsLight.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    elevation: 8,
  ),
  tabBarTheme: TabBarThemeData(
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      color: AppColorsLight.primary,
    ),
    labelColor: AppColorsLight.onPrimary,
    unselectedLabelColor: AppColorsLight.onSurface.withValues(alpha: 0.6),
    indicatorSize: TabBarIndicatorSize.tab,
    splashFactory: NoSplash.splashFactory,
  ),
);

// for dark mode
ThemeData darkMode = ThemeData(
  appBarTheme: AppBarTheme(scrolledUnderElevation: 0.0),
  textTheme: ThemeData.dark().textTheme,
  actionIconTheme: ActionIconThemeData(
    backButtonIconBuilder: (context) =>
        Icon(Icons.arrow_back_ios, size: 22, color: AppColorsDark.onSurface),
  ),
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: AppColorsDark.primary,
    onPrimary: AppColorsDark.onPrimary,
    secondary: AppColorsDark.secondary,
    onSecondary: AppColorsDark.onSecondary,
    error: AppColorsDark.error,
    onError: AppColorsDark.onError,
    surface: AppColorsDark.surface,
    onSurface: AppColorsDark.onSurface,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColorsDark.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 4,
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColorsDark.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    elevation: 8,
  ),
  tabBarTheme: TabBarThemeData(
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      color: AppColorsDark.primary,
    ),
    labelColor: AppColorsDark.onPrimary,
    unselectedLabelColor: AppColorsDark.onSurface.withValues(alpha: 0.6),
    indicatorSize: TabBarIndicatorSize.tab,
    splashFactory: NoSplash.splashFactory,
  ),
);
