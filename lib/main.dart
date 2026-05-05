import 'dart:ui';

import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cumobile/app/app.dart';
import 'package:cumobile/core/services/logging_service.dart';
import 'package:cumobile/core/services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  await configureLogging();
  await ThemeController.instance.load();
  await AppMetrica.activate(
    AppMetricaConfig('a4fd9b5a-d780-4275-bb47-dbd58563d77d'),
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppMetrica.reportErrorWithGroup(
      'flutter_error',
      errorDescription:
          AppMetricaErrorDescription.fromFlutterErrorDetails(details),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppMetrica.reportErrorWithGroup(
      'platform_error',
      errorDescription:
          AppMetricaErrorDescription.fromObjectAndStackTrace(error, stack),
    );
    return false;
  };

  await AppMetrica.reportEvent('app_started');
  runApp(const LMSApp());
}
