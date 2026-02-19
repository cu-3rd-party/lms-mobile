import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cumobile/app/app.dart';
import 'package:cumobile/core/services/logging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  await configureLogging();
  runApp(const CUMobileApp());
}
