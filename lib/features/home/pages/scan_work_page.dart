import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;

class ScanWorkPage extends StatefulWidget {
  const ScanWorkPage({super.key});

  @override
  State<ScanWorkPage> createState() => _ScanWorkPageState();
}

class _ScanWorkPageState extends State<ScanWorkPage> {
  static const _accentColor = Color(0xFF00E676);
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final List<ScanPageData> _pages = [];

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
      if (page.file.existsSync()) {
        page.file.deleteSync();
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
            final pageData = _pages[index];
            return Padding(
              key: ValueKey(pageData.file.path),
              padding: const EdgeInsets.only(bottom: 10),
              child: _ScanPreviewTile(
                index: index + 1,
                pageData: pageData,
                onTap: () => _openPreview(pageData),
                onEdit: () => _editPage(index),
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
      setState(() => _pages.add(ScanPageData(file: processed)));
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
      final additions = <ScanPageData>[];
      for (final shot in shots) {
        final processed = await _processScan(File(shot.path));
        if (processed != null) additions.add(ScanPageData(file: processed));
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
      for (final pageData in _pages) {
        final processedBytes = await _processImageForPdf(pageData);
        final image = pw.MemoryImage(processedBytes);
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

  Future<Uint8List> _processImageForPdf(ScanPageData pageData) async {
    final bytes = await pageData.file.readAsBytes();

    if (pageData.rotationDegrees == 0 && pageData.cropRect == null) {
      return bytes;
    }

    var image = img.decodeImage(bytes);
    if (image == null) return bytes;

    if (pageData.rotationDegrees != 0) {
      image = img.copyRotate(image, angle: pageData.rotationDegrees);
    }

    if (pageData.cropRect != null) {
      final rect = pageData.cropRect!;
      final x = (rect.left * image.width).round();
      final y = (rect.top * image.height).round();
      final w = (rect.width * image.width).round();
      final h = (rect.height * image.height).round();
      image = img.copyCrop(image, x: x, y: y, width: w, height: h);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  Future<void> _openPreview(ScanPageData pageData) async {
    Uint8List? fullPreview;

    if (pageData.hasEdits) {
      final bytes = await pageData.file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image != null) {
        if (pageData.rotationDegrees != 0) {
          image = img.copyRotate(image, angle: pageData.rotationDegrees);
        }
        if (pageData.cropRect != null) {
          final rect = pageData.cropRect!;
          final x = (rect.left * image.width).round();
          final y = (rect.top * image.height).round();
          final w = (rect.width * image.width).round();
          final h = (rect.height * image.height).round();
          image = img.copyCrop(image, x: x, y: y, width: w, height: h);
        }
        fullPreview = Uint8List.fromList(img.encodeJpg(image, quality: 95));
      }
    }

    if (!mounted) return;

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
                  child: fullPreview != null
                      ? Image.memory(
                          fullPreview,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          pageData.file,
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
    if (page.file.existsSync()) {
      page.file.deleteSync();
    }
    setState(() {});
  }

  Future<void> _editPage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    final pageData = _pages[index];
    final result = await Navigator.of(context).push<ScanPageData>(
      MaterialPageRoute(
        builder: (_) => _ImageEditorPage(pageData: pageData),
      ),
    );
    if (result != null && mounted) {
      setState(() => _pages[index] = result);
    }
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
  final ScanPageData pageData;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget dragHandle;

  const _ScanPreviewTile({
    required this.index,
    required this.pageData,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final hasEdits = pageData.hasEdits;
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
                child: pageData.previewCache != null
                    ? Image.memory(
                        pageData.previewCache!,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        pageData.file,
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
                      _formatSize(pageData.file.lengthSync()),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    if (hasEdits) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (pageData.rotationDegrees != 0)
                            _buildEditBadge(Icons.rotate_right, '${pageData.rotationDegrees.toStringAsFixed(1)}°'),
                          if (pageData.cropRect != null) ...[
                            if (pageData.rotationDegrees != 0) const SizedBox(width: 6),
                            _buildEditBadge(Icons.crop, null),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: hasEdits ? const Color(0xFF00E676) : Colors.grey[500],
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

  Widget _buildEditBadge(IconData icon, String? label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF00E676)),
          if (label != null) ...[
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
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

class ScanPageData {
  final File file;
  double rotationDegrees;
  Rect? cropRect;
  Uint8List? previewCache;

  ScanPageData({
    required this.file,
    this.rotationDegrees = 0,
    this.cropRect,
    this.previewCache,
  });

  bool get hasEdits => rotationDegrees != 0 || cropRect != null;

  ScanPageData copyWith({
    File? file,
    double? rotationDegrees,
    Rect? cropRect,
    Uint8List? previewCache,
    bool clearCrop = false,
    bool clearPreview = false,
  }) {
    return ScanPageData(
      file: file ?? this.file,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      cropRect: clearCrop ? null : (cropRect ?? this.cropRect),
      previewCache: clearPreview ? null : (previewCache ?? this.previewCache),
    );
  }
}

class _ImageEditorPage extends StatefulWidget {
  final ScanPageData pageData;

  const _ImageEditorPage({required this.pageData});

  @override
  State<_ImageEditorPage> createState() => _ImageEditorPageState();
}

enum _DragHandle { none, topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, move }

class _ImageEditorPageState extends State<_ImageEditorPage> {
  static const _accentColor = Color(0xFF00E676);
  static const _handleSize = 44.0;
  static const _edgeHandleSize = 32.0;

  late double _rotationDegrees;
  late Rect _cropRect;
  bool _isCropping = false;
  bool _isSaving = false;

  ui.Image? _uiImage;
  Size _imageSize = Size.zero;
  final GlobalKey _imageKey = GlobalKey();

  _DragHandle _activeHandle = _DragHandle.none;
  Offset _dragStart = Offset.zero;
  Rect _cropRectAtDragStart = Rect.zero;

  @override
  void initState() {
    super.initState();
    _rotationDegrees = widget.pageData.rotationDegrees;
    _cropRect = widget.pageData.cropRect ?? const Rect.fromLTRB(0, 0, 1, 1);
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.pageData.file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _uiImage = frame.image;
        _imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      });
    }
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
              child: _uiImage == null
                  ? Center(
                      child: isIos
                          ? const CupertinoActivityIndicator(color: _accentColor)
                          : const CircularProgressIndicator(color: _accentColor),
                    )
                  : _buildImageArea(),
            ),
            _buildToolbar(isIos),
          ],
        ),
      ),
    );

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Редактирование'),
          backgroundColor: const Color(0xFF121212),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CupertinoActivityIndicator(radius: 10)
                : const Text('Готово'),
          ),
        ),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Редактирование'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Готово', style: TextStyle(color: _accentColor)),
                ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildImageArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final radians = _rotationDegrees * math.pi / 180;
        final absCos = math.cos(radians).abs();
        final absSin = math.sin(radians).abs();

        final rotatedWidth = _imageSize.width * absCos + _imageSize.height * absSin;
        final rotatedHeight = _imageSize.width * absSin + _imageSize.height * absCos;

        final scale = math.min(
          constraints.maxWidth / rotatedWidth,
          constraints.maxHeight / rotatedHeight,
        ) * 0.85;

        final displayWidth = rotatedWidth * scale;
        final displayHeight = rotatedHeight * scale;

        final cropPixelRect = Rect.fromLTRB(
          _cropRect.left * displayWidth,
          _cropRect.top * displayHeight,
          _cropRect.right * displayWidth,
          _cropRect.bottom * displayHeight,
        );

        return Center(
          child: Container(
            key: _imageKey,
            width: displayWidth,
            height: displayHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[800]!),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Transform.rotate(
                    angle: radians,
                    child: Image.file(
                      widget.pageData.file,
                      fit: BoxFit.contain,
                      width: _imageSize.width * scale,
                      height: _imageSize.height * scale,
                    ),
                  ),
                ),
                if (_isCropping)
                  _buildCropInterface(displayWidth, displayHeight, cropPixelRect)
                else if (_cropRect != const Rect.fromLTRB(0, 0, 1, 1))
                  _buildCropPreview(cropPixelRect),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCropPreview(Rect cropPixelRect) {
    return CustomPaint(
      painter: _CropOverlayPainter(cropRect: cropPixelRect),
    );
  }

  Widget _buildCropInterface(double displayWidth, double displayHeight, Rect cropPixelRect) {
    return Stack(
      children: [
        // Dark overlay outside crop area
        CustomPaint(
          size: Size(displayWidth, displayHeight),
          painter: _CropOverlayPainter(cropRect: cropPixelRect, isSelecting: true),
        ),
        // Corner handles
        _buildHandle(_DragHandle.topLeft, cropPixelRect.topLeft),
        _buildHandle(_DragHandle.topRight, cropPixelRect.topRight),
        _buildHandle(_DragHandle.bottomLeft, cropPixelRect.bottomLeft),
        _buildHandle(_DragHandle.bottomRight, cropPixelRect.bottomRight),
        // Edge handles
        _buildEdgeHandle(_DragHandle.top, Offset(cropPixelRect.center.dx, cropPixelRect.top), true),
        _buildEdgeHandle(_DragHandle.bottom, Offset(cropPixelRect.center.dx, cropPixelRect.bottom), true),
        _buildEdgeHandle(_DragHandle.left, Offset(cropPixelRect.left, cropPixelRect.center.dy), false),
        _buildEdgeHandle(_DragHandle.right, Offset(cropPixelRect.right, cropPixelRect.center.dy), false),
        // Move handle (center of crop area)
        _buildMoveHandle(cropPixelRect, displayWidth, displayHeight),
      ],
    );
  }

  Widget _buildHandle(_DragHandle handle, Offset position) {
    return Positioned(
      left: position.dx - _handleSize / 2,
      top: position.dy - _handleSize / 2,
      child: GestureDetector(
        onPanStart: (d) => _onHandleDragStart(handle, d),
        onPanUpdate: _onHandleDragUpdate,
        onPanEnd: _onHandleDragEnd,
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle(_DragHandle handle, Offset position, bool isHorizontal) {
    return Positioned(
      left: position.dx - (isHorizontal ? _edgeHandleSize : _edgeHandleSize / 2),
      top: position.dy - (isHorizontal ? _edgeHandleSize / 2 : _edgeHandleSize),
      child: GestureDetector(
        onPanStart: (d) => _onHandleDragStart(handle, d),
        onPanUpdate: _onHandleDragUpdate,
        onPanEnd: _onHandleDragEnd,
        child: Container(
          width: isHorizontal ? _edgeHandleSize * 2 : _edgeHandleSize,
          height: isHorizontal ? _edgeHandleSize : _edgeHandleSize * 2,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: isHorizontal ? 40 : 6,
              height: isHorizontal ? 6 : 40,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoveHandle(Rect cropPixelRect, double displayWidth, double displayHeight) {
    return Positioned(
      left: cropPixelRect.left + _handleSize / 2,
      top: cropPixelRect.top + _handleSize / 2,
      child: GestureDetector(
        onPanStart: (d) => _onHandleDragStart(_DragHandle.move, d),
        onPanUpdate: (d) => _onMoveDragUpdate(d, displayWidth, displayHeight),
        onPanEnd: _onHandleDragEnd,
        child: Container(
          width: (cropPixelRect.width - _handleSize).clamp(0.0, double.infinity),
          height: (cropPixelRect.height - _handleSize).clamp(0.0, double.infinity),
          color: Colors.transparent,
        ),
      ),
    );
  }

  void _onHandleDragStart(_DragHandle handle, DragStartDetails details) {
    _activeHandle = handle;
    _dragStart = details.localPosition;
    _cropRectAtDragStart = _cropRect;
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    if (_activeHandle == _DragHandle.none) return;

    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final delta = details.localPosition - _dragStart;
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    var newRect = _cropRectAtDragStart;
    const minSize = 0.1;

    switch (_activeHandle) {
      case _DragHandle.topLeft:
        newRect = Rect.fromLTRB(
          (newRect.left + dx).clamp(0.0, newRect.right - minSize),
          (newRect.top + dy).clamp(0.0, newRect.bottom - minSize),
          newRect.right,
          newRect.bottom,
        );
        break;
      case _DragHandle.topRight:
        newRect = Rect.fromLTRB(
          newRect.left,
          (newRect.top + dy).clamp(0.0, newRect.bottom - minSize),
          (newRect.right + dx).clamp(newRect.left + minSize, 1.0),
          newRect.bottom,
        );
        break;
      case _DragHandle.bottomLeft:
        newRect = Rect.fromLTRB(
          (newRect.left + dx).clamp(0.0, newRect.right - minSize),
          newRect.top,
          newRect.right,
          (newRect.bottom + dy).clamp(newRect.top + minSize, 1.0),
        );
        break;
      case _DragHandle.bottomRight:
        newRect = Rect.fromLTRB(
          newRect.left,
          newRect.top,
          (newRect.right + dx).clamp(newRect.left + minSize, 1.0),
          (newRect.bottom + dy).clamp(newRect.top + minSize, 1.0),
        );
        break;
      case _DragHandle.top:
        newRect = Rect.fromLTRB(
          newRect.left,
          (newRect.top + dy).clamp(0.0, newRect.bottom - minSize),
          newRect.right,
          newRect.bottom,
        );
        break;
      case _DragHandle.bottom:
        newRect = Rect.fromLTRB(
          newRect.left,
          newRect.top,
          newRect.right,
          (newRect.bottom + dy).clamp(newRect.top + minSize, 1.0),
        );
        break;
      case _DragHandle.left:
        newRect = Rect.fromLTRB(
          (newRect.left + dx).clamp(0.0, newRect.right - minSize),
          newRect.top,
          newRect.right,
          newRect.bottom,
        );
        break;
      case _DragHandle.right:
        newRect = Rect.fromLTRB(
          newRect.left,
          newRect.top,
          (newRect.right + dx).clamp(newRect.left + minSize, 1.0),
          newRect.bottom,
        );
        break;
      default:
        break;
    }

    setState(() => _cropRect = newRect);
  }

  void _onMoveDragUpdate(DragUpdateDetails details, double displayWidth, double displayHeight) {
    if (_activeHandle != _DragHandle.move) return;

    final delta = details.localPosition - _dragStart;
    final dx = delta.dx / displayWidth;
    final dy = delta.dy / displayHeight;

    final width = _cropRectAtDragStart.width;
    final height = _cropRectAtDragStart.height;

    var newLeft = (_cropRectAtDragStart.left + dx).clamp(0.0, 1.0 - width);
    var newTop = (_cropRectAtDragStart.top + dy).clamp(0.0, 1.0 - height);

    setState(() {
      _cropRect = Rect.fromLTWH(newLeft, newTop, width, height);
    });
  }

  void _onHandleDragEnd(DragEndDetails details) {
    _activeHandle = _DragHandle.none;
  }

  Widget _buildToolbar(bool isIos) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
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
              Icon(
                isIos ? CupertinoIcons.rotate_left : Icons.rotate_left,
                color: Colors.grey[400],
                size: 20,
              ),
              Expanded(
                child: isIos
                    ? CupertinoSlider(
                        value: _rotationDegrees,
                        min: -180,
                        max: 180,
                        activeColor: _accentColor,
                        onChanged: (v) => setState(() => _rotationDegrees = v),
                      )
                    : Slider(
                        value: _rotationDegrees,
                        min: -180,
                        max: 180,
                        activeColor: _accentColor,
                        inactiveColor: Colors.grey[700],
                        onChanged: (v) => setState(() => _rotationDegrees = v),
                      ),
              ),
              Icon(
                isIos ? CupertinoIcons.rotate_right : Icons.rotate_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_rotationDegrees.toStringAsFixed(1)}°',
                style: TextStyle(
                  color: _rotationDegrees != 0 ? _accentColor : Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickRotateButton(isIos, -90),
                  const SizedBox(width: 8),
                  _buildQuickRotateButton(isIos, 0, label: '0°'),
                  const SizedBox(width: 8),
                  _buildQuickRotateButton(isIos, 90),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(
                isIos: isIos,
                icon: isIos ? CupertinoIcons.crop : Icons.crop,
                label: _isCropping ? 'Отмена' : 'Обрезать',
                isActive: _isCropping,
                onTap: _toggleCrop,
              ),
              if (_hasCrop)
                _buildToolButton(
                  isIos: isIos,
                  icon: isIos ? CupertinoIcons.clear : Icons.crop_free,
                  label: 'Сбросить',
                  onTap: _resetCrop,
                ),
            ],
          ),
          if (_isCropping) ...[
            const SizedBox(height: 12),
            Text(
              'Выделите область для обрезки',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickRotateButton(bool isIos, double degrees, {String? label}) {
    final isActive = _rotationDegrees == degrees;
    final text = label ?? '${degrees > 0 ? '+' : ''}${degrees.toInt()}°';
    return GestureDetector(
      onTap: () => setState(() => _rotationDegrees = degrees),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withValues(alpha: 0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: _accentColor, width: 1) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? _accentColor : Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required bool isIos,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? _accentColor : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _toggleCrop() {
    setState(() => _isCropping = !_isCropping);
  }

  void _resetCrop() {
    setState(() {
      _cropRect = const Rect.fromLTRB(0, 0, 1, 1);
      _isCropping = false;
    });
  }

  bool get _hasCrop => _cropRect != const Rect.fromLTRB(0, 0, 1, 1);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      Uint8List? preview;
      final hasChanges = _rotationDegrees != 0 || _hasCrop;

      if (hasChanges) {
        preview = await _generatePreview();
      }

      final result = widget.pageData.copyWith(
        rotationDegrees: _rotationDegrees,
        cropRect: _hasCrop ? _cropRect : null,
        previewCache: preview,
        clearCrop: !_hasCrop,
        clearPreview: !hasChanges,
      );
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List?> _generatePreview() async {
    try {
      final bytes = await widget.pageData.file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      if (_rotationDegrees != 0) {
        image = img.copyRotate(image, angle: _rotationDegrees);
      }

      if (_hasCrop) {
        final x = (_cropRect.left * image.width).round();
        final y = (_cropRect.top * image.height).round();
        final w = (_cropRect.width * image.width).round();
        final h = (_cropRect.height * image.height).round();
        image = img.copyCrop(image, x: x, y: y, width: w, height: h);
      }

      // Resize for preview (max 300px on longest side)
      const maxSize = 300;
      if (image.width > maxSize || image.height > maxSize) {
        if (image.width > image.height) {
          image = img.copyResize(image, width: maxSize);
        } else {
          image = img.copyResize(image, height: maxSize);
        }
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      return null;
    }
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool isSelecting;

  _CropOverlayPainter({
    required this.cropRect,
    this.isSelecting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    final borderPaint = Paint()
      ..color = isSelecting ? Colors.white : const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(cropRect, borderPaint);

    if (!isSelecting) {
      final cornerPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      const cornerLength = 20.0;

      canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(cornerLength, 0), cornerPaint);
      canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(0, cornerLength), cornerPaint);

      canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(-cornerLength, 0), cornerPaint);
      canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(0, cornerLength), cornerPaint);

      canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
      canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(0, -cornerLength), cornerPaint);

      canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(-cornerLength, 0), cornerPaint);
      canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(0, -cornerLength), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.isSelecting != isSelecting;
  }
}
