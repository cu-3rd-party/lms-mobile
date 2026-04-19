import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cumobile/core/services/theme_service.dart';
import 'package:cumobile/core/theme/app_theme.dart';
import 'package:cumobile/features/auth/pages/auth_wrapper.dart';

class LMSApp extends StatefulWidget {
  const LMSApp({super.key});

  @override
  State<LMSApp> createState() => _LMSAppState();
}

class _LMSAppState extends State<LMSApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  static const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const _supportedLocales = <Locale>[
    Locale('ru', 'RU'),
    Locale('en', 'US'),
  ];

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.dark;
    final brightness =
        ThemeController.instance.resolveBrightness(platformBrightness);
    final isDark = brightness == Brightness.dark;

    if (Platform.isIOS) {
      return CupertinoApp(
        title: 'LMS',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _supportedLocales,
        theme: isDark ? AppTheme.cupertinoDark() : AppTheme.cupertinoLight(),
        home: const AuthWrapper(),
      );
    }

    return MaterialApp(
      title: 'LMS',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: _supportedLocales,
      theme: AppTheme.materialLight(),
      darkTheme: AppTheme.materialDark(),
      themeMode: ThemeController.instance.mode,
      home: const AuthWrapper(),
    );
  }
}
