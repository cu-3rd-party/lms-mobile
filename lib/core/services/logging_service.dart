import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _maxLogBytes = 1 * 1024 * 1024; // 1 MB

Future<void> configureLogging() async {
  File? logFile;

  if (!kIsWeb) {
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory(p.join(dir.path, 'logs'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      logFile = File(p.join(logDir.path, 'errors.log'));

      // Если файл вырос больше 1 MB — обрезаем, оставляем последние 100 KB
      if (logFile.existsSync() && logFile.lengthSync() > _maxLogBytes) {
        final content = logFile.readAsStringSync();
        final trimmed = content.substring(content.length - 100 * 1024);
        logFile.writeAsStringSync(trimmed);
      }
    } catch (e) {
      debugPrint('Failed to open log file: $e');
      logFile = null;
    }
  }

  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.time.toIso8601String()} '
      '${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint(record.stackTrace.toString());
    }

    if (logFile != null && record.level >= Level.WARNING) {
      _writeRecord(logFile, record);
    }
  });
}

void _writeRecord(File file, LogRecord record) {
  try {
    final buf = StringBuffer();
    buf.writeln(
      '[${record.level.name}] ${record.time.toIso8601String()} '
      '${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      buf.writeln('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      buf.writeln(record.stackTrace.toString());
    }
    buf.writeln();
    file.writeAsStringSync(buf.toString(), mode: FileMode.append);
  } catch (_) {
    // игнорируем ошибки записи в лог-файл
  }
}
