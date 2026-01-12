import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cumobile/features/auth/pages/auth_wrapper.dart';

class CUMobileApp extends StatelessWidget {
  const CUMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoApp(
        title: 'ЦУ',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('en', 'US'),
        ],
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF00E676),
          scaffoldBackgroundColor: const Color(0xFF121212),
          barBackgroundColor: const Color(0xFF121212),
          textTheme: CupertinoTextThemeData(
            textStyle: GoogleFonts.ubuntu(color: CupertinoColors.white),
          ),
        ),
        home: const AuthWrapper(),
      );
    }

    return MaterialApp(
      title: 'ЦУ',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: GoogleFonts.ubuntuTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
