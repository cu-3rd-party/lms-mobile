import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CacheTtl {
  static const short = Duration(days: 7);
  static const long = Duration(days: 30);
}

class _CacheEntry {
  final DateTime savedAt;
  final String body;

  const _CacheEntry(this.savedAt, this.body);
}

class ApiCache {
  ApiCache._();

  static final ApiCache instance = ApiCache._();
  static final Logger _log = Logger('ApiCache');
  static const _dirName = 'api_cache';

  final Map<String, _CacheEntry> _memory = {};
  Future<Directory>? _directory;
  int _generation = 0;

  Future<Directory> _dir() {
    return _directory ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, _dirName));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  static String _fileName(String key) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(key)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final prefix = safe.length > 60 ? safe.substring(0, 60) : safe;
    return '${prefix}_${hash.toRadixString(16)}.cache';
  }

  Future<String?> read(String key, Duration maxAge) async {
    var entry = _memory[key];
    if (entry == null) {
      try {
        final file = File(p.join((await _dir()).path, _fileName(key)));
        if (!await file.exists()) return null;
        final raw = await file.readAsString();
        final newline = raw.indexOf('\n');
        if (newline <= 0) return null;
        final millis = int.tryParse(raw.substring(0, newline));
        if (millis == null) return null;
        entry = _CacheEntry(
          DateTime.fromMillisecondsSinceEpoch(millis),
          raw.substring(newline + 1),
        );
        _memory[key] = entry;
      } catch (e, st) {
        _log.fine('Cache read failed for $key', e, st);
        return null;
      }
    }
    if (DateTime.now().difference(entry.savedAt) > maxAge) return null;
    return entry.body;
  }

  Future<void> write(String key, String body) async {
    final generation = _generation;
    final entry = _CacheEntry(DateTime.now(), body);
    _memory[key] = entry;
    try {
      final dir = await _dir();
      if (generation != _generation) return;
      final file = File(p.join(dir.path, _fileName(key)));
      await file.writeAsString('${entry.savedAt.millisecondsSinceEpoch}\n$body', flush: true);
    } catch (e, st) {
      _log.fine('Cache write failed for $key', e, st);
    }
  }

  Future<Uint8List?> readBytes(String key, Duration maxAge) async {
    final body = await read(key, maxAge);
    if (body == null) return null;
    try {
      return base64Decode(body);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBytes(String key, Uint8List bytes) => write(key, base64Encode(bytes));

  Future<void> remove(String key) async {
    _memory.remove(key);
    try {
      final file = File(p.join((await _dir()).path, _fileName(key)));
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      _log.fine('Cache remove failed for $key', e, st);
    }
  }

  Future<void> clear() async {
    _generation++;
    _memory.clear();
    try {
      final dir = await _dir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e, st) {
      _log.warning('Cache clear failed', e, st);
    }
  }
}
