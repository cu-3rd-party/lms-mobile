import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cumobile/core/theme/app_colors.dart';

class AppTheme {
  static ThemeData materialDark() {
    const c = AppColors.dark;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.background,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E676),
        secondary: Color(0xFF00E676),
        surface: Color(0xFF1E1E1E),
      ),
      textTheme: GoogleFonts.ubuntuTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }

  static ThemeData materialLight() {
    const c = AppColors.light;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.light(
        primary: c.accent,
        secondary: c.accent,
        surface: c.surface,
      ),
      textTheme: GoogleFonts.ubuntuTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }

  static CupertinoThemeData cupertinoDark() {
    const c = AppColors.dark;
    return CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: c.accent,
      scaffoldBackgroundColor: c.background,
      barBackgroundColor: c.background,
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.ubuntu(color: c.textPrimary),
      ),
    );
  }

  static CupertinoThemeData cupertinoLight() {
    const c = AppColors.light;
    return CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: c.accent,
      scaffoldBackgroundColor: c.background,
      barBackgroundColor: c.surface,
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.ubuntu(color: c.textPrimary),
      ),
    );
  }
}
