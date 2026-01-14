import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ScanWorkPage extends StatefulWidget {
  const ScanWorkPage({super.key});

  @override
  State<ScanWorkPage> createState() => _ScanWorkPageState();
}

class _ScanWorkPageState extends State<ScanWorkPage> {
  static const _accentColor = Color(0xFF00E676);
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final List<File> _pages = [];

  bool _isCapturing = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = _defaultName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final page in _pages) {
      if (page.existsSync()) {
        page.deleteSync();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final body = Container(
      color: const Color(0xFF121212),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildScanHero(isIos),
                  const SizedBox(height: 16),
                  _buildNameField(isIos),
                  const SizedBox(height: 16),
                  _buildPages(isIos),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  isIos: isIos,
                  onPressed: _isCapturing ? null : _addPage,
                  label: _isCapturing ? 'Сканирование...' : 'Снять камерой',
                  icon: isIos ? CupertinoIcons.camera_viewfinder : Icons.document_scanner,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSecondaryButton(
                  isIos: isIos,
                  onPressed: _isCapturing ? null : _pickFromGallery,
                  label: 'Из галереи',
                  icon: isIos ? CupertinoIcons.photo_on_rectangle : Icons.photo_library_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
                  _buildPrimaryButton(
                    isIos: isIos,
                    onPressed: _pages.isEmpty || _isSaving ? null : _saveAsPdf,
                    label: _isSaving ? 'Сохраняем...' : 'Сохранить PDF',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Сканирование'),
          backgroundColor: Color(0xFF121212),
        ),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Сканирование работы'),
      ),
      body: body,
    );
  }

  Widget _buildScanHero(bool isIos) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIos ? CupertinoIcons.viewfinder : Icons.document_scanner_outlined,
              color: _accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сканирование работ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Снимите страницы, мы соберём их в один PDF и сохраним во вкладке Файлы.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(bool isIos) {
    final baseDecoration = InputDecoration(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      labelText: 'Имя файла',
      labelStyle: TextStyle(color: Colors.grey[400]),
      hintText: 'Например, Работа_по_математике',
      hintStyle: TextStyle(color: Colors.grey[600]),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _accentColor),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isIos)
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: baseDecoration,
          )
        else
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Имя файла',
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        const SizedBox(height: 6),
        Text(
          'PDF будет сохранён в разделе Файлы и доступен для вложений в комментариях.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPages(bool isIos) {
    if (_pages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isIos ? CupertinoIcons.square_on_square : Icons.layers_outlined,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Пока нет страниц',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Добавьте первую страницу, чтобы собрать PDF.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Страницы',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pages.length,
          onReorder: _reorderPages,
          itemBuilder: (context, index) {
            final file = _pages[index];
            return Padding(
              key: ValueKey(file.path),
              padding: const EdgeInsets.only(bottom: 10),
              child: _ScanPreviewTile(
                index: index + 1,
                file: file,
                onTap: () => _openPreview(file),
                onDelete: () => _removePage(index),
                dragHandle: ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required bool isIos,
    required VoidCallback? onPressed,
    required String label,
  }) {
    if (isIos) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSaving) ...[
              const CupertinoActivityIndicator(color: Colors.black, radius: 9),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(color: Colors.black)),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Сохраняем...'),
                ],
              )
            : Text(label),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required bool isIos,
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
  }) {
    if (isIos) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCapturing) ...[
              const CupertinoActivityIndicator(radius: 8),
              const SizedBox(width: 8),
            ] else ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[700]!),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isCapturing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _addPage() async {
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
      _error = null;
    });
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (shot == null) return;
      final processed = await _processScan(File(shot.path));
      if (processed == null) {
        setState(() => _error = 'Не удалось обработать снимок');
        return;
      }
      setState(() => _pages.add(processed));
    } catch (e) {
      setState(() => _error = 'Не удалось отсканировать страницу');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
      _error = null;
    });
    try {
      final shots = await _picker.pickMultiImage();
      if (shots.isEmpty) return;
      final additions = <File>[];
      for (final shot in shots) {
        final processed = await _processScan(File(shot.path));
        if (processed != null) additions.add(processed);
      }
      if (additions.isNotEmpty) {
        setState(() => _pages.addAll(additions));
      }
    } catch (e) {
      setState(() => _error = 'Не удалось добавить фото');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<File?> _processScan(File source) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final ext = p.extension(source.path).isNotEmpty ? p.extension(source.path) : '.jpg';
      final filename = 'scan_${DateTime.now().millisecondsSinceEpoch}$ext';
      final target = File(p.join(tmpDir.path, filename));
      return await source.copy(target.path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAsPdf() async {
    if (_pages.isEmpty || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final doc = pw.Document();
      for (final page in _pages) {
        final bytes = await page.readAsBytes();
        final image = pw.MemoryImage(bytes);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(
              image,
              fit: pw.BoxFit.cover,
            ),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = _normalizeFileName(_nameController.text.trim());
      final fullPath = await _buildUniquePath(dir, fileName);
      final file = File(fullPath);
      await file.writeAsBytes(await doc.save(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Не удалось сохранить скан');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openPreview(File file) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    final page = _pages.removeAt(index);
    if (page.existsSync()) {
      page.deleteSync();
    }
    setState(() {});
  }

  void _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  String _defaultName() {
    final now = DateTime.now();
    final formatted = DateFormat('dd.MM.yyyy_HH-mm').format(now);
    return 'Скан_$formatted';
  }

  String _normalizeFileName(String value) {
    final trimmed = value.isEmpty ? _defaultName() : value;
    final safe = trimmed.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '').trim();
    if (safe.isEmpty) return _defaultName();
    return safe;
  }

  Future<String> _buildUniquePath(Directory dir, String baseName) async {
    var attempt = 0;
    while (true) {
      final suffix = attempt == 0 ? '' : '__dup$attempt';
      final candidate = p.join(dir.path, '$baseName$suffix.pdf');
      final exists = await File(candidate).exists();
      if (!exists) return candidate;
      attempt++;
    }
  }
}

class _ScanPreviewTile extends StatelessWidget {
  final int index;
  final File file;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Widget dragHandle;

  const _ScanPreviewTile({
    required this.index,
    required this.file,
    required this.onTap,
    required this.onDelete,
    required this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: radius,
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 104,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.hardEdge,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Страница $index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatSize(file.lengthSync()),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              dragHandle,
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
