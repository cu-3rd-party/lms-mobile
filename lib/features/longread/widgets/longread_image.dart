import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/services/api_service.dart';

class LongreadImageCache {
  LongreadImageCache._();

  static final Logger _log = Logger('LongreadImageCache');
  static const _maxConcurrent = 3;
  static const _timeout = Duration(seconds: 30);

  static final Map<String, Future<File?>> _inflight = {};
  static final Map<String, File> _ready = {};
  static final Queue<Completer<void>> _waiting = Queue();
  static int _active = 0;
  static Future<Directory>? _directory;

  static String _key(String filename, String version) => '$filename@$version';

  static File? peek(String filename, String version) => _ready[_key(filename, version)];

  static Future<File?> resolve(String filename, String version) {
    final key = _key(filename, version);
    final ready = _ready[key];
    if (ready != null) return Future.value(ready);
    return _inflight[key] ??= _load(filename, version, key).whenComplete(() {
      _inflight.remove(key);
    });
  }

  static void prefetch(Iterable<(String, String)> images) {
    for (final (filename, version) in images) {
      resolve(filename, version);
    }
  }

  static Future<Directory> _dir() {
    return _directory ??= () async {
      final base = await getApplicationCacheDirectory();
      final dir = Directory(p.join(base.path, 'longread_images'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  static Future<File> _fileFor(String filename, String key) async {
    final extension = p.extension(filename);
    final safeName = key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return File(p.join((await _dir()).path, '$safeName$extension'));
  }

  static Future<File?> _load(String filename, String version, String key) async {
    try {
      final file = await _fileFor(filename, key);
      if (await file.exists() && await file.length() > 0) {
        return _ready[key] = file;
      }
    } catch (e, st) {
      _log.warning('Image cache lookup failed', e, st);
    }

    await _acquire();
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final file = await _download(filename, version, key);
        if (file != null) return _ready[key] = file;
      }
      return null;
    } finally {
      _release();
    }
  }

  static Future<File?> _download(String filename, String version, String key) async {
    try {
      final url = await apiService.getDownloadLink(filename, version).timeout(_timeout);
      if (url == null) return null;
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        _log.warning('Image download failed: ${response.statusCode}');
        return null;
      }
      final file = await _fileFor(filename, key);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (e, st) {
      _log.warning('Error downloading longread image', e, st);
      return null;
    }
  }

  static Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    await completer.future;
  }

  static void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }
}

class LongreadImage extends StatefulWidget {
  final String filename;
  final String version;
  final String? name;

  const LongreadImage({
    super.key,
    required this.filename,
    required this.version,
    this.name,
  });

  @override
  State<LongreadImage> createState() => _LongreadImageState();
}

class _LongreadImageState extends State<LongreadImage> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _file = LongreadImageCache.peek(widget.filename, widget.version);
    if (_file == null) _load();
  }

  Future<void> _load() async {
    final file = await LongreadImageCache.resolve(widget.filename, widget.version);
    if (!mounted) return;
    setState(() {
      _file = file;
      _failed = file == null;
    });
  }

  void _retry() {
    setState(() => _failed = false);
    _load();
  }

  void _openFullscreen(File file) {
    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _FullscreenImage(file: file),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final file = _file;
    Widget child;
    if (file != null) {
      child = GestureDetector(
        onTap: () => _openFullscreen(file),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return image;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: image,
              );
            },
            errorBuilder: (_, _, _) => Container(
              height: 120,
              color: c.surface,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, color: c.textTertiary),
            ),
          ),
        ),
      );
    } else if (_failed) {
      child = GestureDetector(
        onTap: _retry,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isIos ? CupertinoIcons.photo : Icons.broken_image_outlined,
                color: c.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Не удалось загрузить изображение. Нажмите, чтобы повторить',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      child = Container(
        height: 200,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isIos
              ? CupertinoActivityIndicator(color: c.accent)
              : CircularProgressIndicator(color: c.accent),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }
}

class _FullscreenImage extends StatelessWidget {
  final File file;

  const _FullscreenImage({required this.file});

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: Image.file(file)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    isIos ? CupertinoIcons.xmark : Icons.close,
                    color: Colors.white,
                  ),
                  tooltip: 'Закрыть',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
