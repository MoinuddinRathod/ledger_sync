import 'package:flutter/material.dart';

/// ===============================
/// LIGHT MODE COLORS
/// ===============================
/// ===============================
/// LIGHT MODE COLORS (MODERN)
/// ===============================
class AppColorsLight {
  static const Color primary = Color(0xFF6366F1); // Modern, vibrant Indigo
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF818CF8); // Softer accent Indigo
  static const Color onSecondary = Color(0xFFFFFFFF);

  // The biggest change: a clean, cool slate-white instead of heavy lavender
  static const Color surface = Color(0xFFF8FAFC);
  static const Color onSurface = Color(0xFF0F172A); // Very dark slate (softer than pure black)

  static const Color error = Color(0xFFEF4444); // Crisp, modern red
  static const Color onError = Color(0xFFFFFFFF);

  // Extended colors
  static const Color card = Color(0xFFFFFFFF); // Pure white cards contrast beautifully with the surface
  static const Color border = Color(0xFFE2E8F0); // Subtle, elegant border color

  // Dialog/Snackbar Semantic Colors
  static const Color success = Color(0xFF10B981); // Clean emerald green
  static const Color successBg = Color(0xFFD1FAE5); // Very soft emerald background

  static const Color warning = Color(0xFFF59E0B); // Vibrant amber
  static const Color warningBg = Color(0xFFFEF3C7); // Soft amber background

  static const Color errorColor = Color(0xFFEF4444); // Matches main error
  static const Color errorBg = Color(0xFFFEE2E2); // Soft red background

  static const Color info = Color(0xFF3B82F6); // Modern bright blue
  static const Color infoBg = Color(0xFFDBEAFE); // Soft blue background
}

/// ===============================
/// DARK MODE COLORS
/// ===============================
class AppColorsDark {
  static const Color primary = Color(0xFF7C80FF); // Slightly brighter for dark
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF9FA2FF);
  static const Color onSecondary = Color(0xFFFFFFFF);

  static const Color surface = Color(0xFF0F1123); // Deep indigo-black
  static const Color onSurface = Color(0xFFE6E8FF); // Soft lavender text

  static const Color error = Color(0xFFEF5350);
  static const Color onError = Color(0xFFFFFFFF);

  // Optional extended colors
  static const Color card = Color(0xFF1A1C35);
  static const Color border = Color(0xFF2A2D52);
  
  // Dialog/Snackbar Semantic Colors
  static const Color success = Color(0xFF4CA571); // Slightly dimmed for Dark mode
  static const Color successBg = Color(0xFF132A20); // Deep green-tinted dark background
  static const Color warning = Color(0xFFD98E3A); // Slightly dimmed for Dark mode
  static const Color warningBg = Color(0xFF332010); // Deep orange-tinted dark background
  static const Color errorColor = Color(0xFFC24040); // Slightly dimmed for Dark mode
  static const Color errorBg = Color(0xFF331616); // Deep red-tinted dark background
  static const Color info = Color(0xFF6B70E5); // Brightened for Dark mode
  static const Color infoBg = Color(0xFF181938); // Deep indigo-tinted dark background
}
