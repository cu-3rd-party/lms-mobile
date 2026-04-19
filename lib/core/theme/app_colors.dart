import 'package:flutter/material.dart';

class AppColors {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color iconSecondary;
  final Color shadow;
  final Brightness brightness;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.iconSecondary,
    required this.shadow,
    required this.brightness,
  });

  static const AppColors dark = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceVariant: Color(0xFF2A2A2A),
    border: Color(0xFF424242),
    divider: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFBDBDBD),
    textTertiary: Color(0xFF9E9E9E),
    textDisabled: Color(0xFF616161),
    accent: Color(0xFF00E676),
    onAccent: Color(0xFF000000),
    danger: Color(0xFFFF5252),
    iconSecondary: Color(0xFFBDBDBD),
    shadow: Color(0xCC000000),
    brightness: Brightness.dark,
  );

  static const AppColors light = AppColors(
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDEDEF),
    border: Color(0xFFE0E0E0),
    divider: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF121212),
    textSecondary: Color(0xFF555555),
    textTertiary: Color(0xFF757575),
    textDisabled: Color(0xFFBDBDBD),
    accent: Color(0xFF00A152),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD32F2F),
    iconSecondary: Color(0xFF757575),
    shadow: Color(0x33000000),
    brightness: Brightness.light,
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
