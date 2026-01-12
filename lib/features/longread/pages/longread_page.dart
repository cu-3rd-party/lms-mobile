import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/longread_material.dart';
import 'package:cumobile/data/models/task_comment.dart';
import 'package:cumobile/data/models/task_event.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/longread/widgets/attachment_card.dart';
import 'package:cumobile/features/longread/widgets/longread_file_card.dart';

class LongreadPage extends StatefulWidget {
  final Longread longread;
  final Color themeColor;
  final String? courseName;
  final String? themeName;
  final int? selectedTaskId;
  final String? selectedExerciseName;

  const LongreadPage({
    super.key,
    required this.longread,
    required this.themeColor,
    this.courseName,
    this.themeName,
    this.selectedTaskId,
    this.selectedExerciseName,
  });

  @override
  State<LongreadPage> createState() => _LongreadPageState();
}

class _LongreadPageState extends State<LongreadPage> with WidgetsBindingObserver {
  List<LongreadMaterial> _materials = [];
  bool _isLoading = true;
  final Set<String> _downloadingKeys = {};
  final Map<String, double?> _downloadProgress = {};
  final Map<String, String> _downloadSpeed = {};
  final Set<String> _downloadedKeys = {};
  final Map<int, List<TaskEvent>> _eventsByTaskId = {};
  final Map<int, List<TaskComment>> _commentsByTaskId = {};
  final Set<int> _loadingTaskIds = {};
  final Map<int, String?> _taskLoadErrors = {};
  final Map<int, int> _taskTabIndex = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Set<int> _sendingCommentTaskIds = {};
  final Map<int, String?> _commentErrors = {};
  static final Logger _log = Logger('LongreadPage');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMaterials();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDownloadedFlags();
      _refreshDownloadedTaskAttachmentsOnResume();
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await apiService.fetchLongreadMaterials(widget.longread.id);
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
      await _refreshDownloadedFlags();
      await _loadTaskDetails();
    } catch (e, st) {
      _log.warning('Error loading materials', e, st);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDownloadedFlags() async {
    final keys = <String>{};
    for (final material in _materials) {
      if (material.isFile) {
        final fileName = material.contentName ?? material.filename ?? 'file';
        final existingPath = await _getExistingFilePathFor(fileName, material.version);
        if (existingPath != null) {
          keys.add(_materialKey(material));
        }
      }
      if (material.isCoding && material.attachments.isNotEmpty) {
        for (var i = 0; i < material.attachments.length; i++) {
          final attachment = material.attachments[i];
          final existingPath = await _getExistingFilePathFor(attachment.name, attachment.version);
          if (existingPath != null) {
            keys.add(_attachmentKey(material, i));
          }
        }
      }
    }
    if (mounted) {
      setState(() {
        _downloadedKeys
          ..clear()
          ..addAll(keys);
      });
    }
  }

  Future<void> _loadTaskDetails() async {
    final taskIds = _materials
        .where((m) => m.isCoding && m.taskId != null)
        .map((m) => m.taskId!)
        .toSet();

    for (final taskId in taskIds) {
      if (_loadingTaskIds.contains(taskId)) continue;
      _loadingTaskIds.add(taskId);
      try {
        final results = await Future.wait([
          apiService.fetchTaskEvents(taskId),
          apiService.fetchTaskComments(taskId),
        ]);
        if (!mounted) return;
        setState(() {
          _eventsByTaskId[taskId] = results[0] as List<TaskEvent>;
          _commentsByTaskId[taskId] = results[1] as List<TaskComment>;
          _taskLoadErrors[taskId] = null;
        });
        await _refreshDownloadedTaskAttachments(taskId);
      } catch (e, st) {
        _log.warning('Error loading task details', e, st);
        if (mounted) {
          setState(() => _taskLoadErrors[taskId] = 'Не удалось загрузить историю');
        }
      } finally {
        _loadingTaskIds.remove(taskId);
      }
    }
  }

  Future<void> _refreshDownloadedTaskAttachmentsOnResume() async {
    final taskIds = _eventsByTaskId.keys.toList();
    for (final taskId in taskIds) {
      await _refreshDownloadedTaskAttachments(taskId);
    }
  }

  Future<void> _downloadFile(LongreadMaterial material) async {
    if (material.filename == null || material.version == null) return;

    final fileName = material.contentName ?? material.filename ?? 'file';
    final key = _materialKey(material);
    final existingPath = await _getExistingFilePathFor(fileName, material.version);
    if (existingPath != null) {
      if (mounted) {
        setState(() => _downloadedKeys.add(key));
      }
      await OpenFilex.open(existingPath);
      return;
    }

    if (mounted) {
      setState(() {
        _downloadingKeys.add(key);
        _downloadProgress[key] = 0.0;
        _downloadSpeed[key] = '';
      });
    }

    try {
      final url = await apiService.getDownloadLink(
        material.filename!,
        material.version!,
      );

      if (url == null) return;

      _log.info('Download url: $url');
      final filePath = await _downloadToDevice(url, fileName, material.version, key);
      if (filePath == null) return;

      if (mounted) {
        setState(() => _downloadedKeys.add(key));
      }
      await OpenFilex.open(filePath);
    } catch (e, st) {
      _log.warning('Error downloading file', e, st);
    } finally {
      if (mounted) {
        setState(() {
          _downloadingKeys.remove(key);
          _downloadProgress.remove(key);
          _downloadSpeed.remove(key);
        });
      }
    }
  }

  Future<void> _refreshDownloadedTaskAttachments(int taskId) async {
    final keys = <String>{};
    final events = _eventsByTaskId[taskId] ?? [];
    final comments = _commentsByTaskId[taskId] ?? [];
    for (final event in events) {
      for (final attachment in event.content.attachments) {
        final existingPath = await _getExistingFilePathFor(
          attachment.name,
          attachment.version,
        );
        if (existingPath != null) {
          keys.add(_taskAttachmentKey(taskId, attachment));
        }
      }
    }
    for (final comment in comments) {
      for (final attachment in comment.attachments) {
        final existingPath = await _getExistingFilePathFor(
          attachment.name,
          attachment.version,
        );
        if (existingPath != null) {
          keys.add(_taskAttachmentKey(taskId, attachment));
        }
      }
    }
    if (mounted && keys.isNotEmpty) {
      setState(() => _downloadedKeys.addAll(keys));
    }
  }

  Future<void> _downloadAttachment(
    MaterialAttachment attachment,
    String key,
  ) async {
    final existingPath = await _getExistingFilePathFor(attachment.name, attachment.version);
    if (existingPath != null) {
      if (mounted) {
        setState(() => _downloadedKeys.add(key));
      }
      await OpenFilex.open(existingPath);
      return;
    }

    if (mounted) {
      setState(() {
        _downloadingKeys.add(key);
        _downloadProgress[key] = 0.0;
        _downloadSpeed[key] = '';
      });
    }

    try {
      final url = await apiService.getDownloadLink(
        attachment.filename,
        attachment.version,
      );
      if (url == null) return;

      final filePath = await _downloadToDevice(url, attachment.name, attachment.version, key);
      if (filePath == null) return;

      if (mounted) {
        setState(() => _downloadedKeys.add(key));
      }
      await OpenFilex.open(filePath);
    } catch (e, st) {
      _log.warning('Error downloading attachment', e, st);
    } finally {
      if (mounted) {
        setState(() {
          _downloadingKeys.remove(key);
          _downloadProgress.remove(key);
          _downloadSpeed.remove(key);
        });
      }
    }
  }

  Future<String?> _downloadToDevice(
    String url,
    String fileName,
    String? version,
    String key,
  ) async {
    try {
      final path = await _getLocalFilePath(fileName, version);

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);
        if (response.statusCode != 200) {
          _log.warning('Download failed: ${response.statusCode}');
          return null;
        }

        final total = response.contentLength ?? -1;
        final file = File(path);
        final sink = file.openWrite();
        var received = 0;
        final startedAt = DateTime.now();
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (mounted) {
            if (total > 0) {
              _downloadProgress[key] = received / total;
            } else {
              _downloadProgress[key] = null;
            }
            final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
            if (elapsedMs > 0) {
              final bytesPerSec = received / (elapsedMs / 1000);
              _downloadSpeed[key] = _formatSpeed(bytesPerSec);
            }
            setState(() {});
          }
        }
        await sink.flush();
        await sink.close();
        return file.path;
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.warning('Failed to save file', e, st);
      return null;
    }
  }

  Future<String> _getLocalFilePath(String fileName, String? version) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = _buildSafeFileName(fileName, version);
    return p.join(dir.path, safeName);
  }

  Future<String?> _getExistingFilePathFor(String fileName, String? version) async {
    final path = await _getLocalFilePath(fileName, version);
    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    return null;
  }

  String _buildSafeFileName(String name, String? version) {
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (version == null || version.isEmpty) return safeName;
    final ext = p.extension(safeName);
    if (ext.isEmpty) {
      return '${safeName}_$version';
    }
    final base = safeName.substring(0, safeName.length - ext.length);
    return '${base}_$version$ext';
  }

  String _materialKey(LongreadMaterial material) => 'm:${material.id}';

  String _attachmentKey(LongreadMaterial material, int index) {
    final attachment = material.attachments[index];
    return 'a:${material.id}:$index:${attachment.filename}:${attachment.version}';
  }

  String _taskAttachmentKey(int taskId, MaterialAttachment attachment) {
    return 't:$taskId:${attachment.filename}:${attachment.version}';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    if (bytesPerSecond >= mb) {
      return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond >= kb) {
      return '${(bytesPerSecond / kb).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year} ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final body = _isLoading
        ? Center(
            child: isIos
                ? const CupertinoActivityIndicator(
                    radius: 14,
                    color: Color(0xFF00E676),
                  )
                : const CircularProgressIndicator(color: Color(0xFF00E676)),
          )
        : _materials.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIos ? CupertinoIcons.folder : Icons.folder_open,
                      color: Colors.grey[600],
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Нет материалов',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            : _buildMaterialsList();

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.longread.name),
        ),
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(top: false, child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.longread.name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }

  Widget _buildMaterialsList() {
    final filteredMaterials = widget.selectedTaskId != null
        ? _materials
            .where((m) => m.isCoding && m.taskId == widget.selectedTaskId)
            .toList()
        : widget.selectedExerciseName != null
            ? _materials
                .where((m) => m.isCoding && m.name == widget.selectedExerciseName)
                .toList()
            : _materials;
    final hasMarkdown = filteredMaterials.any((m) => m.isMarkdown);
    final seenTaskIds = <int>{};
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMaterials.length,
      itemBuilder: (context, index) {
        final material = filteredMaterials[index];
        if (material.isMarkdown) {
          return _buildMarkdownCard(material);
        } else if (material.isFile) {
          return _buildFileCard(material);
        } else if (material.isCoding) {
          final taskId = material.taskId;
          if (taskId != null && !seenTaskIds.add(taskId)) {
            return const SizedBox.shrink();
          }
          return _buildCodingCard(material, hasMarkdown: hasMarkdown);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMarkdownCard(LongreadMaterial material) {
    final content = _normalizeHtmlColors(material.viewContent ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Html(
        data: content,
        style: {
          "body": Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(14),
            color: Colors.white,
            lineHeight: LineHeight(1.5),
          ),
          "a": Style(
            color: widget.themeColor,
            textDecoration: TextDecoration.underline,
          ),
          "p": Style(
            margin: Margins.only(bottom: 8),
          ),
          "hr": Style(
            margin: Margins.symmetric(vertical: 8),
            height: Height(1),
            border: Border(bottom: BorderSide(color: Colors.white, width: 1)),
          ),
        },
        onLinkTap: (url, context, attributes) async {
          if (url != null) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  String _normalizeHtmlColors(String html) {
    final colorStyle = RegExp("color\\s*:\\s*[^;\"']+;?", caseSensitive: false);
    final cleaned = html.replaceAll(colorStyle, '');
    final emptyDoubleStyle = RegExp(r'style=\"\\s*;*\\s*\"', caseSensitive: false);
    final emptySingleStyle = RegExp(r"style='\\s*;*\\s*'", caseSensitive: false);
    return cleaned.replaceAll(emptyDoubleStyle, '').replaceAll(emptySingleStyle, '');
  }

  String _normalizeCommentHtml(String html) {
    var cleaned = _normalizeHtmlColors(html);
    cleaned = cleaned.replaceAll(RegExp(r'</?table[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</?(tbody|thead|tfoot)[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</?tr[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</?td[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</?colgroup[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<col[^>]*>', caseSensitive: false), '');
    final anchor = RegExp(r'(<a\\b[^>]*>)([^<]+)(</a>)', caseSensitive: false);
    return cleaned.replaceAllMapped(anchor, (match) {
      final prefix = match.group(1)!;
      final text = match.group(2)!;
      final suffix = match.group(3)!;
      return '$prefix${_softWrapLongWord(text)}$suffix';
    });
  }

  String _softWrapLongWord(String text) {
    if (text.length <= 24) return text;
    const chunkSize = 16;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % chunkSize == 0) {
        buffer.write('\u200B');
      }
    }
    return buffer.toString();
  }

  Widget _buildFileCard(LongreadMaterial material) {
    final fileName = material.contentName ?? material.filename ?? 'Файл';
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';
    final key = _materialKey(material);
    final isDownloading = _downloadingKeys.contains(key);
    final progress = _downloadProgress[key];
    final speed = _downloadSpeed[key] ?? '';
    final isDownloaded = _downloadedKeys.contains(key);

    return LongreadFileCard(
      fileName: fileName,
      extension: extension,
      formattedSize: material.formattedSize,
      isDownloading: isDownloading,
      progress: progress,
      speed: speed,
      isDownloaded: isDownloaded,
      themeColor: widget.themeColor,
      onTap: isDownloading ? null : () => _downloadFile(material),
    );
  }

  Widget _buildCodingCard(LongreadMaterial material, {required bool hasMarkdown}) {
    final shouldShowDescription =
        (material.viewContent ?? '').isNotEmpty && !hasMarkdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shouldShowDescription) _buildMarkdownCard(material),
        if (material.attachments.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Файлы задания',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          ...material.attachments.asMap().entries.map(
                (entry) => _buildAttachmentCard(material, entry.key, entry.value),
              ),
        ],
        if (material.taskId != null) _buildTaskTabs(material),
      ],
    );
  }

  Widget _buildAttachmentCard(
    LongreadMaterial material,
    int index,
    MaterialAttachment attachment,
  ) {
    final key = _attachmentKey(material, index);
    return AttachmentCard(
      fileName: attachment.name,
      extension: attachment.extension,
      formattedSize: attachment.formattedSize,
      isDownloading: _downloadingKeys.contains(key),
      progress: _downloadProgress[key],
      isDownloaded: _downloadedKeys.contains(key),
      themeColor: widget.themeColor,
      onTap: () => _downloadAttachment(attachment, key),
    );
  }

  Widget _buildTaskTabs(LongreadMaterial material) {
    final taskId = material.taskId!;
    final events = _eventsByTaskId[taskId] ?? [];
    final comments = _commentsByTaskId[taskId] ?? [];
    final isLoading = _loadingTaskIds.contains(taskId) && events.isEmpty && comments.isEmpty;
    final isIos = Platform.isIOS;

    if (isIos) {
      final selectedIndex = _taskTabIndex[taskId] ?? 0;
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CupertinoSlidingSegmentedControl<int>(
              groupValue: selectedIndex,
              thumbColor: const Color(0xFF1E1E1E),
              backgroundColor: const Color(0xFF121212),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Text('Решение'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Text('Комментарии'),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Text('Информация'),
                ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                setState(() => _taskTabIndex[taskId] = value);
              },
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(selectedIndex),
                color: const Color(0xFF121212),
                child: selectedIndex == 1
                    ? _buildCommentsTab(taskId, comments, isLoading)
                    : selectedIndex == 2
                        ? _buildInfoTab(material, events, isLoading)
                        : _buildSolutionTab(taskId, material, events, isLoading),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: TabBar(
                isScrollable: false,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: widget.themeColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: const [
                  Tab(text: 'Решение'),
                  Tab(text: 'Комментарии'),
                  Tab(text: 'Информация'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final index = controller.index;
                    Widget content;
                    switch (index) {
                      case 1:
                        content = _buildCommentsTab(taskId, comments, isLoading);
                        break;
                      case 2:
                        content = _buildInfoTab(material, events, isLoading);
                        break;
                      default:
                        content = _buildSolutionTab(taskId, material, events, isLoading);
                    }
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        key: ValueKey(index),
                        color: const Color(0xFF121212),
                        child: content,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionTab(
    int taskId,
    LongreadMaterial material,
    List<TaskEvent> events,
    bool isLoading,
  ) {
    if (isLoading) {
      return Center(
        child: Platform.isIOS
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    final error = _taskLoadErrors[taskId];
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Platform.isIOS
                ? CupertinoButton(
                    onPressed: () => _reloadTaskDetails(taskId),
                    child: const Text('Повторить'),
                  )
                : TextButton(
                    onPressed: () => _reloadTaskDetails(taskId),
                    child: const Text('Повторить'),
                  ),
          ],
        ),
      );
    }

    final sortedEvents = _sortEvents(events);
    if (sortedEvents.isEmpty) {
      return Center(
        child: Text(
          'История пока пуста',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final event = sortedEvents[index];
        return _buildEventCard(taskId, event);
      },
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemCount: sortedEvents.length,
    );
  }

  Widget _buildCommentsTab(
    int taskId,
    List<TaskComment> comments,
    bool isLoading,
  ) {
    final composer = _buildCommentComposer(taskId);
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          composer,
          const SizedBox(height: 12),
          Center(
            child: Platform.isIOS
                ? const CupertinoActivityIndicator(
                    radius: 14,
                    color: Color(0xFF00E676),
                  )
                : const CircularProgressIndicator(color: Color(0xFF00E676)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        composer,
        const SizedBox(height: 12),
        if (comments.isEmpty)
          Text(
            'Комментариев нет',
            style: TextStyle(color: Colors.grey[500]),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.only(top: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final comment = comments[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.sender.name,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (comment.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Html(
                        data: _normalizeCommentHtml(comment.content),
                        extensions: const [TableHtmlExtension()],
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(13),
                            color: Colors.white,
                            lineHeight: LineHeight(1.4),
                          ),
                          "a": Style(
                            color: widget.themeColor,
                            textDecoration: TextDecoration.underline,
                          ),
                          "table": Style(color: Colors.white),
                          "tr": Style(color: Colors.white),
                          "td": Style(color: Colors.white),
                          "div": Style(color: Colors.white),
                          "span": Style(color: Colors.white),
                        },
                        onLinkTap: (url, context, attributes) async {
                          if (url != null) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                    ],
                    if (comment.attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...comment.attachments.map(
                        (attachment) => _buildTaskAttachmentCard(taskId, attachment),
                      ),
                    ],
                  ],
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemCount: comments.length,
          ),
      ],
    );
  }

  Widget _buildCommentComposer(int taskId) {
    final controller = _commentControllerFor(taskId);
    final error = _commentErrors[taskId];
    final isIos = Platform.isIOS;
    return Focus(
      onFocusChange: (_) => setState(() {}),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
        final isShiftPressed = pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.shiftRight);
        if (event.logicalKey == LogicalKeyboardKey.enter && !isShiftPressed) {
          final hasText = controller.text.trim().isNotEmpty;
          final isSending = _sendingCommentTaskIds.contains(taskId);
          if (hasText && !isSending) {
            _submitComment(taskId);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final hasText = value.text.trim().isNotEmpty;
          final isFocused = Focus.of(context).hasFocus;
          final isSending = _sendingCommentTaskIds.contains(taskId);
          final placeholder = isFocused ? '' : 'Напишите комментарий';
          final borderColor = error != null
              ? Colors.redAccent
              : isFocused
                  ? widget.themeColor.withValues(alpha: 0.8)
                  : Colors.grey[700]!;
          final fillColor = hasText ? const Color(0xFF242424) : const Color(0xFF1E1E1E);
          final isEnabled = hasText && !isSending;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: isIos
                          ? CupertinoTextField(
                              controller: controller,
                              placeholder: placeholder,
                              placeholderStyle:
                                  TextStyle(color: Colors.grey[600], fontSize: 12),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              cursorColor: widget.themeColor,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              decoration: const BoxDecoration(),
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              onChanged: (text) => _clearCommentError(taskId, text),
                            )
                          : TextField(
                              controller: controller,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              onChanged: (text) => _clearCommentError(taskId, text),
                              cursorColor: widget.themeColor,
                              decoration: InputDecoration.collapsed(
                                hintText: placeholder,
                                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    isIos
                        ? CupertinoButton(
                            onPressed: isEnabled ? () => _submitComment(taskId) : null,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: isEnabled
                                ? widget.themeColor
                                : const Color(0xFF3A3A3A),
                            minimumSize: Size.zero,
                            child: isSending
                                ? const CupertinoActivityIndicator(
                                    radius: 9,
                                    color: CupertinoColors.black,
                                  )
                                : const Text(
                                    'Отправить',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                          )
                        : ElevatedButton(
                            onPressed: isEnabled ? () => _submitComment(taskId) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnabled
                                  ? widget.themeColor
                                  : Colors.grey[700],
                              foregroundColor: Colors.black,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle:
                                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: isSending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text('Отправить'),
                          ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  TextEditingController _commentControllerFor(int taskId) {
    return _commentControllers.putIfAbsent(taskId, () => TextEditingController());
  }

  void _clearCommentError(int taskId, String value) {
    if (_commentErrors[taskId] == null) return;
    if (value.trim().isEmpty) return;
    setState(() => _commentErrors[taskId] = null);
  }

  Future<void> _submitComment(int taskId) async {
    final controller = _commentControllerFor(taskId);
    final rawText = controller.text.trim();
    if (rawText.isEmpty) {
      setState(() => _commentErrors[taskId] = 'Введите текст комментария');
      return;
    }

    setState(() {
      _sendingCommentTaskIds.add(taskId);
      _commentErrors[taskId] = null;
    });

    try {
      final commentId = await apiService.createTaskComment(
        taskId: taskId,
        content: _commentTextToHtml(rawText),
        attachments: const [],
      );
      if (!mounted) return;
      if (commentId == null) {
        setState(() => _commentErrors[taskId] = 'Не удалось отправить комментарий');
        return;
      }
      controller.clear();
      final updated = await apiService.fetchTaskComments(taskId);
      if (!mounted) return;
      setState(() {
        _commentsByTaskId[taskId] = updated;
      });
      await _refreshDownloadedTaskAttachments(taskId);
    } catch (e, st) {
      _log.warning('Error sending comment', e, st);
      if (mounted) {
        setState(() => _commentErrors[taskId] = 'Не удалось отправить комментарий');
      }
    } finally {
      if (mounted) {
        setState(() => _sendingCommentTaskIds.remove(taskId));
      } else {
        _sendingCommentTaskIds.remove(taskId);
      }
    }
  }

  String _commentTextToHtml(String text) {
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(text);
    return '<p>${escaped.replaceAll('\n', '<br>')}</p>';
  }

  Widget _buildInfoTab(
    LongreadMaterial material,
    List<TaskEvent> events,
    bool isLoading,
  ) {
    if (isLoading && events.isEmpty) {
      return Center(
        child: Platform.isIOS
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    final TaskEventEstimation? eventEstimation = _latestEstimation(events);
    final materialEstimation = material.estimation;
    final deadline = eventEstimation?.deadline ?? materialEstimation?.deadline;
    final activityName = eventEstimation?.activityName ?? materialEstimation?.activityName;
    final scoreText = _formatScore(
      events,
      eventEstimation?.maxScore,
      materialEstimation?.maxScore,
    );
    final status = _deriveStatus(events);

    return Column(
      children: [
        _buildInfoRow('Дедлайн', _formatDateTime(deadline)),
        _buildInfoRow('Статус', status),
        _buildInfoRow('Тип активности', activityName ?? '-'),
        _buildInfoRow('Название курса', widget.courseName ?? '-'),
        _buildInfoRow('Тема', widget.themeName ?? '-'),
        _buildInfoRow('Оценка', scoreText),
        _buildInfoRow('Дополнительный балл', '-'),
      ],
    );
  }

  Widget _buildEventCard(int taskId, TaskEvent event) {
    final authorName = _eventAuthorName(event);
    final isSystem = _isSystemEvent(event);
    final initials = isSystem ? 'СП' : _initials(authorName);
    final scoreText = _eventScoreLabel(event);
    final statusBadge = _eventStatusBadge(event);
    final bodyText = _eventBodyText(event);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSystem
                  ? Colors.grey[800]
                  : widget.themeColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSystem ? Colors.grey[300] : widget.themeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(event.occurredOn),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    if (scoreText.isNotEmpty || statusBadge != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (scoreText.isNotEmpty)
                            Text(
                              scoreText,
                              style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                            ),
                          if (statusBadge != null) ...[
                            if (scoreText.isNotEmpty) const SizedBox(height: 4),
                            statusBadge,
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
                if (bodyText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bodyText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                  ),
                ],
                if (event.content.solutionUrl != null &&
                    event.content.solutionUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSolutionLink(event),
                ],
                if (event.content.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Прикрепленные файлы:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 6),
                  ...event.content.attachments.map(
                    (attachment) => _buildTaskAttachmentCard(taskId, attachment),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionLink(TaskEvent event) {
    final isIos = Platform.isIOS;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIos ? CupertinoIcons.link : Icons.link,
            size: 14,
            color: widget.themeColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Ссылка на решение',
              style: TextStyle(fontSize: 12, color: widget.themeColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    Future<void> onTap() async {
      final uri = Uri.tryParse(event.content.solutionUrl ?? '');
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return isIos
        ? GestureDetector(
            onTap: onTap,
            child: content,
          )
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: content,
          );
  }

  String _eventAuthorName(TaskEvent event) {
    if (_isSystemEvent(event)) return 'Системный пользователь';
    final actorName = event.actorName?.trim();
    if (actorName != null && actorName.isNotEmpty && actorName != 'System') {
      return actorName;
    }
    final reviewerName = event.content.reviewerName;
    if (reviewerName != null && reviewerName.isNotEmpty) {
      return reviewerName;
    }
    final reviewersNames = event.content.reviewersNames ?? const [];
    if (reviewersNames.isNotEmpty) {
      return reviewersNames.join(', ');
    }
    final actorEmail = event.actorEmail?.trim();
    if (actorEmail != null && actorEmail.isNotEmpty) {
      return actorEmail;
    }
    return 'Пользователь';
  }

  bool _isSystemEvent(TaskEvent event) {
    final actorName = event.actorName?.trim();
    if (actorName == 'System') return true;
    final actorEmail = event.actorEmail?.trim();
    return actorEmail == 'system@cu.ru';
  }

  String _eventScoreLabel(TaskEvent event) {
    final value = event.content.score?.value;
    final max = event.content.estimation?.maxScore;
    if (value == null && max == null) return '';
    final valueText = value?.toString() ?? '-';
    return max != null ? '$valueText / $max' : valueText;
  }

  Widget? _eventStatusBadge(TaskEvent event) {
    if (event.type == 'taskEvaluated') {
      return _statusBadge('Сдано', const Color(0xFF00E676));
    }
    final state = event.content.taskState ?? event.content.state;
    if (event.type == 'taskCreated' && state == 'backlog') {
      return _statusBadge('Бэклог', Colors.grey);
    }
    return null;
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _eventBodyText(TaskEvent event) {
    switch (event.type) {
      case 'taskEvaluated':
        final value = event.content.score?.value;
        return value != null ? 'Задание принято на $value баллов' : '';
      case 'reviewerAssigned':
        final reviewer = event.content.reviewerName;
        return reviewer != null && reviewer.isNotEmpty
            ? 'Назначен проверяющий $reviewer'
            : 'Назначен проверяющий';
      case 'exerciseReviewersAssigned':
        final reviewers = event.content.reviewersNames ?? const [];
        return reviewers.isNotEmpty
            ? 'Назначены проверяющие: ${reviewers.join(', ')}'
            : 'Назначены проверяющие';
      case 'exerciseReviewersReleased':
        final reviewers = event.content.reviewersNames ?? const [];
        return reviewers.isNotEmpty
            ? 'Проверяющий освобожден: ${reviewers.join(', ')}'
            : 'Проверяющий освобожден';
      case 'solutionAttached':
        return '';
      case 'taskStarted':
        return 'Задание начато';
      case 'taskCompleted':
        return 'Задание отправлено на проверку';
      case 'taskCreated':
        final deadline = event.content.estimation?.deadline ?? event.content.taskDeadline;
        return deadline != null
            ? 'Задание выдано. Дедлайн ${_formatDateTime(deadline)}'
            : 'Задание выдано';
      case 'exerciseEstimated':
        return 'Выставлены параметры';
      case 'exerciseAttachmentsChanged':
        return 'Файлы задания обновлены';
      case 'exerciseChanged':
        final name = event.content.exerciseName;
        return name != null && name.isNotEmpty ? 'Задание обновлено: $name' : 'Задание обновлено';
      default:
        return '';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.first.toString();
    final second = parts[1].characters.first.toString();
    return (first + second).toUpperCase();
  }

  static const _hiddenEventTypes = {
    'exerciseReviewersAssigned',
    'exerciseEstimated',
    'exerciseAttachmentsChanged',
    'exerciseChanged',
  };

  List<TaskEvent> _sortEvents(List<TaskEvent> events) {
    final filtered = events.where((e) {
      return !_hiddenEventTypes.contains(e.type);
    }).toList();
    filtered.sort((a, b) {
      final aTime = a.occurredOn;
      final bTime = b.occurredOn;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return filtered;
  }

  Future<void> _reloadTaskDetails(int taskId) async {
    if (_loadingTaskIds.contains(taskId)) return;
    _loadingTaskIds.add(taskId);
    try {
      final results = await Future.wait([
        apiService.fetchTaskEvents(taskId),
        apiService.fetchTaskComments(taskId),
      ]);
      if (!mounted) return;
      setState(() {
        _eventsByTaskId[taskId] = results[0] as List<TaskEvent>;
        _commentsByTaskId[taskId] = results[1] as List<TaskComment>;
        _taskLoadErrors[taskId] = null;
      });
      await _refreshDownloadedTaskAttachments(taskId);
    } catch (e, st) {
      _log.warning('Error reloading task details', e, st);
      if (mounted) {
        setState(() => _taskLoadErrors[taskId] = 'Не удалось загрузить историю');
      }
    } finally {
      _loadingTaskIds.remove(taskId);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  TaskEventEstimation? _latestEstimation(List<TaskEvent> events) {
    TaskEventEstimation? latest;
    DateTime? latestTime;
    for (final event in events) {
      if (event.content.estimation == null) continue;
      if (event.occurredOn == null) {
        latest ??= event.content.estimation;
        continue;
      }
      if (latestTime == null || event.occurredOn!.isAfter(latestTime)) {
        latest = event.content.estimation;
        latestTime = event.occurredOn;
      }
    }
    return latest;
  }

  String _formatScore(List<TaskEvent> events, int? maxScore, int? fallbackMax) {
    int? value;
    DateTime? latest;
    for (final event in events) {
      final scoreValue = event.content.score?.value;
      if (scoreValue == null) continue;
      if (event.occurredOn == null) {
        value ??= scoreValue;
        continue;
      }
      if (latest == null || event.occurredOn!.isAfter(latest)) {
        value = scoreValue;
        latest = event.occurredOn;
      }
    }
    if (value == null) return '-';
    final max = maxScore ?? fallbackMax;
    return max != null ? '$value/$max' : '$value';
  }

  String _deriveStatus(List<TaskEvent> events) {
    final types = events.map((e) => e.type).toSet();
    if (types.contains('taskEvaluated')) return 'Проверено';
    if (types.contains('taskCompleted') || events.any((e) => e.content.state == 'review')) {
      return 'На проверке';
    }
    if (types.contains('taskStarted')) return 'В работе';
    return 'Не начато';
  }

  Widget _buildTaskAttachmentCard(int taskId, MaterialAttachment attachment) {
    final key = _taskAttachmentKey(taskId, attachment);
    return AttachmentCard(
      fileName: attachment.name,
      extension: attachment.extension,
      formattedSize: attachment.formattedSize,
      isDownloading: _downloadingKeys.contains(key),
      progress: _downloadProgress[key],
      isDownloaded: _downloadedKeys.contains(key),
      themeColor: widget.themeColor,
      size: AttachmentCardSize.compact,
      onTap: () => _downloadAttachment(attachment, key),
    );
  }
}
