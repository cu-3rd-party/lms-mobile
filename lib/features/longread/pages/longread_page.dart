import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/longread_material.dart';
import 'package:cumobile/data/models/task_comment.dart';
import 'package:cumobile/data/models/task_details.dart';
import 'package:cumobile/data/models/task_event.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/longread/widgets/attachment_card.dart';
import 'package:cumobile/features/longread/widgets/longread_file_card.dart';

class LongreadPage extends StatefulWidget {
  final Longread longread;
  final Color themeColor;
  final String? courseName;
  final String? themeName;
  final int? courseId;
  final int? themeId;
  final int? selectedTaskId;
  final String? selectedExerciseName;

  const LongreadPage({
    super.key,
    required this.longread,
    required this.themeColor,
    this.courseName,
    this.themeName,
    this.courseId,
    this.themeId,
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
  final Map<int, TaskDetails> _taskDetailsById = {};
  final Set<int> _loadingTaskIds = {};
  final Map<int, String?> _taskLoadErrors = {};
  final Map<int, int> _taskTabIndex = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<int, TextEditingController> _solutionUrlControllers = {};
  final Set<int> _sendingCommentTaskIds = {};
  final Set<int> _sendingSolutionTaskIds = {};
  final Map<int, String?> _commentErrors = {};
  final Map<int, String?> _solutionErrors = {};
  final Map<int, List<_PendingCommentAttachment>> _pendingCommentAttachments = {};
  final Map<int, List<_PendingCommentAttachment>> _pendingSolutionAttachments = {};
  final Map<int, List<MaterialAttachment>> _editingSolutionAttachments = {};
  final Map<int, bool> _isEditingSolution = {};
  static final Logger _log = Logger('LongreadPage');

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<int, String> _highlightedHtmlByMaterialId = {};
  List<GlobalKey> _searchMatchKeys = [];
  int _searchMatchCount = 0;
  int _activeMatchIndex = 0;
  final ScrollController _materialsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMaterials();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _materialsScrollController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    for (final controller in _solutionUrlControllers.values) {
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
      _updateSearchResults(scrollToFirst: false);
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
          apiService.fetchTaskDetails(taskId),
        ]);
        if (!mounted) return;
        setState(() {
          _eventsByTaskId[taskId] = results[0] as List<TaskEvent>;
          _commentsByTaskId[taskId] = results[1] as List<TaskComment>;
          final details = results[2] as TaskDetails?;
          if (details != null) {
            _taskDetailsById[taskId] = details;
          }
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
    final details = _taskDetailsById[taskId];
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
    for (final attachment in details?.solutionAttachments ?? const []) {
      final existingPath = await _getExistingFilePathFor(
        attachment.name,
        attachment.version,
      );
      if (existingPath != null) {
        keys.add(_taskAttachmentKey(taskId, attachment));
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
          middle: _isSearching
              ? CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Поиск...',
                  placeholderStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  autofocus: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onChanged: _onSearchChanged,
                )
              : Text(
                  widget.longread.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _searchMatchCount > 0 ? _goToPreviousMatch : null,
                    child: Icon(
                      CupertinoIcons.chevron_up,
                      size: 18,
                      color: _searchMatchCount > 0 ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  Text(
                    _searchMatchCount == 0
                        ? '0/0'
                        : '${_activeMatchIndex + 1}/$_searchMatchCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _searchMatchCount > 0 ? _goToNextMatch : null,
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 18,
                      color: _searchMatchCount > 0 ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _closeSearch,
                    child: const Text('Отмена', style: TextStyle(fontSize: 14)),
                  ),
                ]
              else
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _isSearching = true),
                  child: const Icon(CupertinoIcons.search, size: 22),
                ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(top: false, bottom: false, child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.arrow_back, color: Colors.white),
          onPressed: _isSearching ? _closeSearch : () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Поиск...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: _onSearchChanged,
              )
            : Text(
                widget.longread.name,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        toolbarHeight: _isSearching ? kToolbarHeight : kToolbarHeight + 20,
        centerTitle: false,
        actions: [
          if (_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
              onPressed: _searchMatchCount > 0 ? _goToPreviousMatch : null,
              tooltip: 'Предыдущее совпадение',
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _searchMatchCount == 0
                      ? '0/0'
                      : '${_activeMatchIndex + 1}/$_searchMatchCount',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: _searchMatchCount > 0 ? _goToNextMatch : null,
              tooltip: 'Следующее совпадение',
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: body,
    );
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _updateSearchResults(scrollToFirst: false);
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _updateSearchResults(scrollToFirst: true);
  }

  void _updateSearchResults({required bool scrollToFirst}) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _highlightedHtmlByMaterialId.clear();
        _searchMatchKeys = [];
        _searchMatchCount = 0;
        _activeMatchIndex = 0;
      });
      return;
    }

    final highlighted = <int, String>{};
    var nextIndex = 0;
    for (final material in _getFilteredMaterials()) {
      if (!material.isMarkdown) continue;
      final raw = _normalizeHtmlColors(material.viewContent ?? '');
      final startIndex = nextIndex;
      final updated = _highlightHtml(raw, query, () => nextIndex++);
      if (nextIndex != startIndex) {
        highlighted[material.id] = updated;
      }
    }

    final matchCount = nextIndex;
    setState(() {
      _highlightedHtmlByMaterialId
        ..clear()
        ..addAll(highlighted);
      _searchMatchCount = matchCount;
      _searchMatchKeys = List.generate(matchCount, (_) => GlobalKey());
      _activeMatchIndex = matchCount > 0 ? 0 : 0;
    });

    if (scrollToFirst && matchCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch(0));
    }
  }

  String _highlightHtml(
    String html,
    String query,
    int Function() nextIndex,
  ) {
    final document = html_parser.parse(html);

    bool isWithinTag(dom.Node node, Set<String> tagNames) {
      dom.Node? current = node.parentNode;
      while (current != null) {
        if (current is dom.Element) {
          final name = current.localName;
          if (name != null && tagNames.contains(name)) {
            return true;
          }
        }
        current = current.parentNode;
      }
      return false;
    }

    void highlightNode(dom.Node node) {
      if (node.nodeType == dom.Node.TEXT_NODE) {
        if (isWithinTag(node, {'pre', 'code'})) {
          return;
        }
        final text = node.text ?? '';
        if (text.isEmpty) return;
        final lower = text.toLowerCase();
        final matchIndex = lower.indexOf(query);
        if (matchIndex == -1) return;

        final parent = node.parentNode;
        if (parent == null) return;

        final newNodes = <dom.Node>[];
        var start = 0;
        var index = matchIndex;
        while (index != -1) {
          if (index > start) {
            newNodes.add(dom.Text(text.substring(start, index)));
          }
          final mark = dom.Element.tag('mark');
          mark.attributes['data-search-index'] = nextIndex().toString();
          mark.text = text.substring(index, index + query.length);
          newNodes.add(mark);
          start = index + query.length;
          index = lower.indexOf(query, start);
        }
        if (start < text.length) {
          newNodes.add(dom.Text(text.substring(start)));
        }

        final insertIndex = parent.nodes.indexOf(node);
        if (insertIndex != -1) {
          parent.nodes.removeAt(insertIndex);
          parent.nodes.insertAll(insertIndex, newNodes);
        }
        return;
      }

      final children = node.nodes.toList();
      for (final child in children) {
        highlightNode(child);
      }
    }

    highlightNode(document.body ?? document.documentElement!);
    return document.body?.innerHtml ?? html;
  }

  void _goToNextMatch() {
    if (_searchMatchCount == 0) return;
    final next = (_activeMatchIndex + 1) % _searchMatchCount;
    _setActiveMatch(next);
  }

  void _goToPreviousMatch() {
    if (_searchMatchCount == 0) return;
    final prev = (_activeMatchIndex - 1 + _searchMatchCount) % _searchMatchCount;
    _setActiveMatch(prev);
  }

  void _setActiveMatch(int index) {
    setState(() => _activeMatchIndex = index);
    _scrollToMatch(index);
  }

  void _scrollToMatch(int index) {
    if (index < 0 || index >= _searchMatchKeys.length) return;
    final context = _searchMatchKeys[index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Код скопирован'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  List<LongreadMaterial> _getFilteredMaterials() {
    if (widget.selectedTaskId != null) {
      return _materials
          .where((m) => m.isCoding && m.taskId == widget.selectedTaskId)
          .toList();
    }
    if (widget.selectedExerciseName != null) {
      return _materials
          .where((m) => m.isCoding && m.name == widget.selectedExerciseName)
          .toList();
    }
    return _materials;
  }

  Widget _buildMaterialsList() {
    final filteredMaterials = _getFilteredMaterials();
    final hasMarkdown = filteredMaterials.any((m) => m.isMarkdown);
    final seenTaskIds = <int>{};
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final items = <Widget>[];
    for (final material in filteredMaterials) {
      if (material.isMarkdown) {
        items.add(_buildMarkdownCard(material));
      } else if (material.isFile) {
        items.add(_buildFileCard(material));
      } else if (material.isCoding) {
        final taskId = material.taskId;
        if (taskId != null && !seenTaskIds.add(taskId)) {
          continue;
        }
        items.add(_buildCodingCard(material, hasMarkdown: hasMarkdown));
      } else if (material.isQuestions) {
        items.add(_buildQuestionsUnsupportedCard());
      }
    }
    return ListView(
      controller: _materialsScrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      children: items,
    );
  }

  Widget _buildQuestionsUnsupportedCard() {
    final courseId = widget.courseId;
    final themeId = widget.themeId;
    final longreadId = widget.longread.id;
    final link = (courseId != null && themeId != null)
        ? Uri.parse(
            'https://my.centraluniversity.ru/learn/courses/view/actual/$courseId/themes/$themeId/longreads/$longreadId',
          )
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.grey[400], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Тесты пока не поддерживаются. '
                  'Можно пройти тест на сайте.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                ),
                if (link != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      if (await canLaunchUrl(link)) {
                        await launchUrl(link, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      'Открыть тест',
                      style: TextStyle(fontSize: 12, color: widget.themeColor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownCard(LongreadMaterial material) {
    final content = _highlightedHtmlByMaterialId[material.id] ??
        _normalizeHtmlColors(material.viewContent ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SelectionArea(
        child: Html(
          data: content,
          extensions: [
          TagExtension(
            tagsToExtend: {"mark"},
            builder: (extensionContext) {
              final indexAttr = extensionContext.element?.attributes['data-search-index'];
              final matchIndex = int.tryParse(indexAttr ?? '');
              final text = extensionContext.element?.text ?? '';
              final isActive = matchIndex != null && matchIndex == _activeMatchIndex;
              final background = (isActive
                      ? const Color(0xFF00E676)
                      : const Color(0xFF00E676))
                  .withValues(alpha: isActive ? 0.35 : 0.2);
              final key = matchIndex != null && matchIndex < _searchMatchKeys.length
                  ? _searchMatchKeys[matchIndex]
                  : null;
              return Builder(
                builder: (context) {
                  final baseStyle = DefaultTextStyle.of(context).style;
                  return SelectableText(
                    text,
                    key: key,
                    style: baseStyle.copyWith(
                      backgroundColor: background,
                      color: baseStyle.color ?? Colors.white,
                    ),
                  );
                },
              );
            },
          ),
          TagExtension(
            tagsToExtend: {"pre"},
            builder: (extensionContext) {
              final codeElement = extensionContext.element?.children
                  .where((e) => e.localName == 'code')
                  .firstOrNull;

              final code = codeElement?.text ?? extensionContext.element?.text ?? '';

              String? language;
              final classAttr = codeElement?.attributes['class'] ??
                  extensionContext.element?.attributes['class'] ?? '';
              final langMatch = RegExp(r'language-(\w+)').firstMatch(classAttr);
              if (langMatch != null) {
                language = langMatch.group(1);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12, top: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF272822),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      color: const Color(0xFF1E1E1E),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (language ?? 'code').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            onPressed: () => _copyToClipboard(code.trimRight()),
                            icon: Icon(
                              Platform.isIOS
                                  ? CupertinoIcons.doc_on_doc
                                  : Icons.copy,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            tooltip: 'Копировать код',
                          ),
                        ],
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: HighlightView(
                              code.trim(),
                              language: language ?? 'plaintext',
                              theme: monokaiSublimeTheme,
                              padding: const EdgeInsets.all(12),
                              textStyle: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          ],
          style: {
            "body": Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(14),
              color: Colors.white,
              lineHeight: LineHeight(1.5),
            ),
            "mark": Style(
              backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.2),
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
            "code": Style(
              backgroundColor: const Color(0xFF2A2A2A),
              color: const Color(0xFFE6DB74),
              fontFamily: 'monospace',
              fontSize: FontSize(13),
              padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            ),
            "blockquote": Style(
              backgroundColor: const Color(0xFF1A1A2E),
              border: const Border(left: BorderSide(color: Color(0xFF00E676), width: 3)),
              padding: HtmlPaddings.only(left: 12, top: 8, bottom: 8, right: 8),
              margin: Margins.only(bottom: 12, top: 8),
            ),
            "strong": Style(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            "em": Style(
              fontStyle: FontStyle.italic,
            ),
            "ul": Style(
              padding: HtmlPaddings.only(left: 16),
              margin: Margins.only(bottom: 8),
            ),
            "ol": Style(
              padding: HtmlPaddings.only(left: 16),
              margin: Margins.only(bottom: 8),
            ),
            "li": Style(
              padding: HtmlPaddings.only(left: 4),
              margin: Margins.only(bottom: 4),
            ),
            "br": Style(
              display: Display.block,
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            "h3": Style(
              margin: Margins.only(bottom: 8, top: 12),
            ),
            "h4": Style(
              margin: Margins.only(bottom: 6, top: 10),
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
      ),
    );
  }

  String _normalizeHtmlColors(String html) {
    // Process style attributes to handle colors properly for dark theme
    final stylePattern = RegExp(r'style\s*=\s*"([^"]*)"', caseSensitive: false);

    var result = html.replaceAllMapped(stylePattern, (match) {
      final styleContent = match.group(1) ?? '';
      final processedStyle = _processStyleForDarkTheme(styleContent);
      if (processedStyle.isEmpty) {
        return '';
      }
      return 'style="$processedStyle"';
    });

    // Also handle single-quoted styles
    final singleQuotePattern = RegExp(r"style\s*=\s*'([^']*)'", caseSensitive: false);
    result = result.replaceAllMapped(singleQuotePattern, (match) {
      final styleContent = match.group(1) ?? '';
      final processedStyle = _processStyleForDarkTheme(styleContent);
      if (processedStyle.isEmpty) {
        return '';
      }
      return "style='$processedStyle'";
    });

    return result;
  }

  String _processStyleForDarkTheme(String styleContent) {
    final styles = <String, String>{};

    // Parse style properties
    final props = styleContent.split(';');
    for (final prop in props) {
      final colonIndex = prop.indexOf(':');
      if (colonIndex == -1) continue;
      final key = prop.substring(0, colonIndex).trim().toLowerCase();
      final value = prop.substring(colonIndex + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        styles[key] = value;
      }
    }

    final bgColor = styles['background-color'] ?? styles['background'];
    final resultStyles = <String>[];

    // Check if background is light and should be inverted/removed
    final bgBrightness = bgColor != null ? _getColorBrightness(bgColor) : null;
    final isLightBackground = bgBrightness != null && bgBrightness > 180;

    for (final entry in styles.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'color') {
        if (isLightBackground) {
          // Light background will be removed, so invert dark text to light
          final textBrightness = _getColorBrightness(value);
          if (textBrightness != null && textBrightness < 128) {
            // Dark text on light bg -> make it white for dark theme
            // Skip - let default white text show
          } else {
            resultStyles.add('$key: $value');
          }
        } else if (bgColor != null) {
          // Has non-light background, keep original color
          resultStyles.add('$key: $value');
        } else {
          // No background - check if it's a dark color
          final isDark = _isDarkColor(value);
          if (!isDark) {
            resultStyles.add('$key: $value');
          }
        }
      } else if (key == 'background-color' || key == 'background') {
        if (isLightBackground) {
          // Skip light backgrounds - they look bad on dark theme
          // Don't add to result
        } else {
          // Keep dark/colored backgrounds
          resultStyles.add('$key: $value');
        }
      } else if (key == 'font-size' || key == 'font-weight' || key == 'font-style' ||
                 key == 'text-decoration' || key == 'text-align') {
        // Keep text formatting styles
        resultStyles.add('$key: $value');
      }
    }

    return resultStyles.join('; ');
  }

  double? _getColorBrightness(String colorValue) {
    final rgbMatch = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(colorValue);
    if (rgbMatch != null) {
      final r = int.tryParse(rgbMatch.group(1) ?? '') ?? 0;
      final g = int.tryParse(rgbMatch.group(2) ?? '') ?? 0;
      final b = int.tryParse(rgbMatch.group(3) ?? '') ?? 0;
      return (r * 299 + g * 587 + b * 114) / 1000;
    }

    final rgbaMatch = RegExp(r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(colorValue);
    if (rgbaMatch != null) {
      final r = int.tryParse(rgbaMatch.group(1) ?? '') ?? 0;
      final g = int.tryParse(rgbaMatch.group(2) ?? '') ?? 0;
      final b = int.tryParse(rgbaMatch.group(3) ?? '') ?? 0;
      return (r * 299 + g * 587 + b * 114) / 1000;
    }

    final hexMatch = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})').firstMatch(colorValue);
    if (hexMatch != null) {
      final hex = hexMatch.group(1)!;
      int r, g, b;
      if (hex.length == 3) {
        r = int.parse('${hex[0]}${hex[0]}', radix: 16);
        g = int.parse('${hex[1]}${hex[1]}', radix: 16);
        b = int.parse('${hex[2]}${hex[2]}', radix: 16);
      } else {
        r = int.parse(hex.substring(0, 2), radix: 16);
        g = int.parse(hex.substring(2, 4), radix: 16);
        b = int.parse(hex.substring(4, 6), radix: 16);
      }
      return (r * 299 + g * 587 + b * 114) / 1000;
    }

    // Named colors
    const namedBrightness = {
      'white': 255.0, 'snow': 255.0, 'ivory': 255.0,
      'black': 0.0, 'navy': 30.0, 'darkblue': 35.0,
    };
    return namedBrightness[colorValue.toLowerCase()];
  }

  bool _isDarkColor(String colorValue) {
    // Check if color is dark (would be invisible on dark background)
    final rgbMatch = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(colorValue);
    if (rgbMatch != null) {
      final r = int.tryParse(rgbMatch.group(1) ?? '') ?? 0;
      final g = int.tryParse(rgbMatch.group(2) ?? '') ?? 0;
      final b = int.tryParse(rgbMatch.group(3) ?? '') ?? 0;
      // Calculate perceived brightness (standard formula)
      final brightness = (r * 299 + g * 587 + b * 114) / 1000;
      return brightness < 128; // Dark if brightness is less than 50%
    }

    final rgbaMatch = RegExp(r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(colorValue);
    if (rgbaMatch != null) {
      final r = int.tryParse(rgbaMatch.group(1) ?? '') ?? 0;
      final g = int.tryParse(rgbaMatch.group(2) ?? '') ?? 0;
      final b = int.tryParse(rgbaMatch.group(3) ?? '') ?? 0;
      final brightness = (r * 299 + g * 587 + b * 114) / 1000;
      return brightness < 128;
    }

    // Check hex colors
    final hexMatch = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})').firstMatch(colorValue);
    if (hexMatch != null) {
      final hex = hexMatch.group(1)!;
      int r, g, b;
      if (hex.length == 3) {
        r = int.parse('${hex[0]}${hex[0]}', radix: 16);
        g = int.parse('${hex[1]}${hex[1]}', radix: 16);
        b = int.parse('${hex[2]}${hex[2]}', radix: 16);
      } else {
        r = int.parse(hex.substring(0, 2), radix: 16);
        g = int.parse(hex.substring(2, 4), radix: 16);
        b = int.parse(hex.substring(4, 6), radix: 16);
      }
      final brightness = (r * 299 + g * 587 + b * 114) / 1000;
      return brightness < 128;
    }

    // Check named colors that are dark
    final darkColors = {'black', 'darkblue', 'darkgreen', 'darkred', 'navy', 'maroon', 'purple'};
    return darkColors.contains(colorValue.toLowerCase());
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
        if (material.taskId != null) ...[
          _buildTaskSummary(material),
          _buildTaskTabs(material),
        ],
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
            Container(
              color: const Color(0xFF121212),
              child: selectedIndex == 1
                  ? _buildCommentsTab(taskId, comments, isLoading)
                  : selectedIndex == 2
                      ? _buildInfoTab(material, events, isLoading)
                      : _buildSolutionTab(taskId, material, events, isLoading),
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
                    return Container(
                      color: const Color(0xFF121212),
                      child: content,
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
    final details = _taskDetailsById[taskId];
    final existingSolutionAttachments = details?.solutionAttachments ?? const [];
    final derivedStatus = _deriveStatus(events, details);
    final isInProgress = details?.state == 'inProgress' || derivedStatus == 'В работе';
    final hasSolutionData =
        (details?.solutionUrl?.isNotEmpty ?? false) || existingSolutionAttachments.isNotEmpty;
    final canEdit = isInProgress;
    final rawEditing = _isEditingSolution[taskId] ?? (!hasSolutionData && canEdit);
    final isEditing = canEdit ? rawEditing : false;
    final existingForEdit =
        _editingSolutionAttachments[taskId] ?? existingSolutionAttachments;
    final composer =
        isEditing && canEdit ? _buildSolutionComposer(taskId, existingForEdit) : null;

    final showCurrentSolution = hasSolutionData && !isEditing;
    final currentSolutionSection =
        showCurrentSolution ? _buildCurrentSolutionView(taskId, details, canEdit, isEditing) : null;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currentSolutionSection != null) ...[
            currentSolutionSection,
            const SizedBox(height: 12),
          ],
          if (composer != null) ...[
            composer,
            const SizedBox(height: 12),
          ],
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

    final error = _taskLoadErrors[taskId];
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currentSolutionSection != null) ...[
            currentSolutionSection,
            const SizedBox(height: 12),
          ],
          if (composer != null) ...[
            composer,
            const SizedBox(height: 12),
          ],
          Center(
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
          ),
        ],
      );
    }

    final sortedEvents = _sortEvents(events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentSolutionSection != null) ...[
          currentSolutionSection,
          const SizedBox(height: 12),
        ],
        if (composer != null) ...[
          composer,
          const SizedBox(height: 12),
        ],
        if (sortedEvents.isEmpty)
          Center(
            child: Text(
              'История пока пуста',
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.only(top: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final event = sortedEvents[index];
              return _buildEventCard(taskId, event);
            },
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemCount: sortedEvents.length,
          ),
      ],
    );
  }

  Widget _buildSolutionComposer(
    int taskId,
    List<MaterialAttachment> existingAttachments,
  ) {
    final urlController = _solutionUrlControllerFor(taskId);
    final error = _solutionErrors[taskId];
    final isIos = Platform.isIOS;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: urlController,
      builder: (context, value, child) {
        final existing =
            _editingSolutionAttachments[taskId] ?? existingAttachments;
        final pending = _pendingSolutionAttachments[taskId] ?? [];
        final isSending = _sendingSolutionTaskIds.contains(taskId);
        final isUploading = pending.any(
          (item) =>
              item.status == _AttachmentUploadStatus.uploading && item.progress < 1,
        );
        final hasReadyAttachments = pending.any(_isAttachmentReady);
        final urlText = value.text.trim();
        final hasUrl = urlText.isNotEmpty;
        final isUrlValid = !hasUrl || _isValidUrl(urlText);
        final hasFailed =
            pending.any((item) => item.status == _AttachmentUploadStatus.failed);
        final isEnabled = (hasUrl || hasReadyAttachments || existing.isNotEmpty) &&
            isUrlValid &&
            !isSending &&
            !isUploading &&
            !hasFailed;
        final borderColor = (error != null || (hasUrl && !isUrlValid))
            ? Colors.redAccent
            : Colors.grey[700]!.withValues(alpha: 0.7);

        final urlField = isIos
            ? CupertinoTextField(
                controller: urlController,
                placeholder: 'Ссылка на решение (опционально)',
                placeholderStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: widget.themeColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: const BoxDecoration(),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearSolutionError(taskId),
              )
            : TextField(
                controller: urlController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearSolutionError(taskId),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF242424),
                  labelText: 'Ссылка на решение (опционально)',
                  labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: widget.themeColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  urlField,
                  if (existing.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Прикрепленные файлы',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < existing.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242424),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_file,
                                  size: 14,
                                  color: widget.themeColor,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  child: Text(
                                    existing[i].name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: isSending || isUploading
                                      ? null
                                      : () => _removeExistingSolutionAttachment(
                                            taskId,
                                            i,
                                          ),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: isSending || isUploading
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (isIos)
                        CupertinoButton(
                          onPressed:
                              isSending ? null : () => _pickSolutionAttachments(taskId),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: const Color(0xFF2A2A2A),
                          minimumSize: const Size(32, 32),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.paperclip,
                                size: 16,
                                color: isSending ? Colors.grey[600] : widget.themeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Файл',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSending ? Colors.grey[600] : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed:
                              isSending ? null : () => _pickSolutionAttachments(taskId),
                          icon: Icon(
                            Icons.attach_file,
                            size: 16,
                            color: isSending ? Colors.grey[600] : widget.themeColor,
                          ),
                          label: Text(
                            'Файл',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSending ? Colors.grey[600] : Colors.white,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A2A),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      const Spacer(),
                      if (isIos)
                        CupertinoButton(
                          onPressed: isEnabled ? () => _submitSolution(taskId) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          color:
                              isEnabled ? widget.themeColor : const Color(0xFF3A3A3A),
                          minimumSize: const Size(32, 32),
                          borderRadius: BorderRadius.circular(8),
                          child: isSending
                              ? const CupertinoActivityIndicator(
                                  radius: 9,
                                  color: CupertinoColors.black,
                                )
                              : const Text(
                                  'Отправить решение',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                        )
                      else
                        ElevatedButton(
                          onPressed: isEnabled ? () => _submitSolution(taskId) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isEnabled ? widget.themeColor : Colors.grey[700],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            minimumSize: const Size(0, 34),
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
                            : const Text('Отправить решение'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildPendingAttachments(
                taskId,
                pending,
                storage: _pendingSolutionAttachments,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Можно менять решение до дедлайна, после — отправим его на проверку',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildCurrentSolutionView(
    int taskId,
    TaskDetails? details,
    bool canEdit,
    bool isEditing,
  ) {
    if (details == null) return null;
    final hasUrl = details.solutionUrl?.isNotEmpty ?? false;
    final attachments = details.solutionAttachments;
    if (!hasUrl && attachments.isEmpty) return null;
    final isIos = Platform.isIOS;
    final editButton = canEdit && !isEditing
        ? (isIos
            ? CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: widget.themeColor,
                onPressed: () => _startSolutionEdit(taskId, details),
                child: const Text(
                  'Изменить решение',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => _startSolutionEdit(taskId, details),
                child: const Text('Изменить решение'),
              ))
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Текущее решение',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (editButton != null) editButton,
            ],
          ),
          if (hasUrl) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(details.solutionUrl ?? '');
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
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
                        details.solutionUrl ?? '',
                        style: TextStyle(fontSize: 12, color: widget.themeColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Прикрепленные файлы',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),
            ...attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildTaskAttachmentCard(taskId, attachment),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _startSolutionEdit(int taskId, TaskDetails? details) {
    final existing = List<MaterialAttachment>.from(
      details?.solutionAttachments ?? const [],
    );
    _solutionUrlControllerFor(taskId).text = details?.solutionUrl ?? '';
    setState(() {
      _isEditingSolution[taskId] = true;
      _editingSolutionAttachments[taskId] = existing;
      _pendingSolutionAttachments.remove(taskId);
      _solutionErrors[taskId] = null;
    });
  }

  void _removeExistingSolutionAttachment(int taskId, int index) {
    final existing = _editingSolutionAttachments[taskId] ??
        _taskDetailsById[taskId]?.solutionAttachments ??
        const [];
    if (index >= existing.length) return;
    setState(() {
      _editingSolutionAttachments[taskId] = [...existing]..removeAt(index);
    });
  }

  Widget _buildCommentsTab(
    int taskId,
    List<TaskComment> comments,
    bool isLoading,
  ) {
    final composer = _buildCommentComposer(taskId);
    final displayComments = comments.reversed.toList();
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
        if (displayComments.isEmpty)
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
              final comment = displayComments[index];
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
            itemCount: displayComments.length,
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
          final pending = _pendingCommentAttachments[taskId] ?? [];
          final isUploading = pending.any(
            (item) =>
                item.status == _AttachmentUploadStatus.uploading && item.progress < 1,
          );
          final hasUploadedAttachments = pending.any(_isAttachmentReady);
          final placeholder = isFocused ? '' : 'Напишите комментарий';
          final borderColor = error != null
              ? Colors.redAccent
              : isFocused
                  ? widget.themeColor.withValues(alpha: 0.8)
                  : Colors.grey[700]!;
          final fillColor = hasText ? const Color(0xFF242424) : const Color(0xFF1E1E1E);
          final isEnabled =
              (hasText || hasUploadedAttachments) && !isSending && !isUploading;
          _log.fine(
            'Comment UI state: taskId=$taskId hasText=$hasText pending=${pending.length} '
            'hasUploaded=$hasUploadedAttachments isSending=$isSending isUploading=$isUploading '
            'enabled=$isEnabled',
          );
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                              textAlignVertical: TextAlignVertical.center,
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
                    if (isIos)
                      CupertinoButton(
                        onPressed: isSending ? null : () => _pickCommentAttachments(taskId),
                        padding: EdgeInsets.zero,
                        child: Icon(
                          CupertinoIcons.paperclip,
                          size: 18,
                          color: isSending ? Colors.grey[600] : Colors.grey[400],
                        ),
                      )
                    else
                      IconButton(
                        onPressed: isSending ? null : () => _pickCommentAttachments(taskId),
                        icon: Icon(
                          Icons.attach_file,
                          size: 18,
                          color: isSending ? Colors.grey[600] : Colors.grey[400],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Прикрепить файл',
                      ),
                    const SizedBox(width: 4),
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
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildPendingAttachments(taskId, pending),
              ],
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

  Widget _buildPendingAttachments(
    int taskId,
    List<_PendingCommentAttachment> pending, {
    Map<int, List<_PendingCommentAttachment>>? storage,
  }) {
    final targetStorage = storage ?? _pendingCommentAttachments;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < pending.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAttachmentReady(pending[i])
                      ? Icons.check_circle
                      : pending[i].status == _AttachmentUploadStatus.failed
                          ? Icons.error
                          : Icons.insert_drive_file,
                  size: 14,
                  color: pending[i].status == _AttachmentUploadStatus.failed
                      ? Colors.redAccent
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pending[i].name,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pending[i].status == _AttachmentUploadStatus.failed)
                        Text(
                          pending[i].error ?? 'Ошибка загрузки',
                          style:
                              const TextStyle(color: Colors.redAccent, fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (pending[i].status == _AttachmentUploadStatus.uploading &&
                    pending[i].progress < 1)
                  SizedBox(
                    width: 40,
                    child: LinearProgressIndicator(
                      value: pending[i].progress,
                      backgroundColor: Colors.grey[800],
                      color: widget.themeColor,
                    ),
                  )
                else
                  Text(
                    _formatBytes(pending[i].length),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: pending[i].status == _AttachmentUploadStatus.uploading &&
                          pending[i].progress < 1
                      ? null
                      : () => _removePendingAttachment(
                            taskId,
                            i,
                            storage: targetStorage,
                          ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  TextEditingController _commentControllerFor(int taskId) {
    return _commentControllers.putIfAbsent(taskId, () => TextEditingController());
  }

  TextEditingController _solutionUrlControllerFor(int taskId) {
    return _solutionUrlControllers.putIfAbsent(taskId, () => TextEditingController());
  }

  void _clearCommentError(int taskId, String value) {
    if (_commentErrors[taskId] == null) return;
    if (value.trim().isEmpty) return;
    setState(() => _commentErrors[taskId] = null);
  }

  void _clearSolutionError(int taskId) {
    if (_solutionErrors[taskId] == null) return;
    setState(() => _solutionErrors[taskId] = null);
  }

  Future<void> _pickCommentAttachments(int taskId) async {
    try {
      final quick = await _pickRecentScan();
      if (quick != null) {
        await _addPendingAttachments(taskId, [quick]);
        return;
      }

      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      final additions = await Future.wait(
        result.files.map(_pendingFromPlatformFile),
      );
      final filtered = additions.whereType<_PendingCommentAttachment>().toList();
      if (filtered.isEmpty) return;
      await _addPendingAttachments(taskId, filtered);
    } catch (e, st) {
      _log.warning('Error picking attachments', e, st);
      setState(() => _commentErrors[taskId] = 'Не удалось выбрать файл');
    }
  }

  Future<void> _pickSolutionAttachments(int taskId) async {
    try {
      final quick = await _pickRecentScan();
      if (quick != null) {
        await _addPendingAttachments(
          taskId,
          [quick],
          storage: _pendingSolutionAttachments,
          errorMap: _solutionErrors,
          directoryBuilder: (id) => 'tasks/$id/solutions',
          uploadContext: 'solution',
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      final additions = await Future.wait(
        result.files.map(_pendingFromPlatformFile),
      );
      final filtered = additions.whereType<_PendingCommentAttachment>().toList();
      if (filtered.isEmpty) return;
      await _addPendingAttachments(
        taskId,
        filtered,
        storage: _pendingSolutionAttachments,
        errorMap: _solutionErrors,
        directoryBuilder: (id) => 'tasks/$id/solutions',
        uploadContext: 'solution',
      );
    } catch (e, st) {
      _log.warning('Error picking solution attachments', e, st);
      setState(() => _solutionErrors[taskId] = 'Не удалось выбрать файл');
    }
  }

  Future<_PendingCommentAttachment?> _pendingFromPlatformFile(
    PlatformFile file,
  ) async {
    final path = file.path;
    if (path == null) return null;
    final contentType = lookupMimeType(path) ?? 'application/octet-stream';
    final mediaType = contentType.startsWith('image/') ? 'image' : 'file';
    final normalizedName = _normalizeFilename(p.basename(path), contentType);
    return _PendingCommentAttachment(
      file: File(path),
      name: normalizedName,
      length: file.size,
      contentType: contentType,
      mediaType: mediaType,
      status: _AttachmentUploadStatus.queued,
      progress: 0,
    );
  }

  Future<void> _addPendingAttachments(
    int taskId,
    List<_PendingCommentAttachment> additions, {
    Map<int, List<_PendingCommentAttachment>>? storage,
    Map<int, String?>? errorMap,
    String Function(int taskId)? directoryBuilder,
    String uploadContext = 'comment',
  }) async {
    if (additions.isEmpty) return;
    final target = storage ?? _pendingCommentAttachments;
    final pending = target[taskId] ?? [];
    setState(() {
      target[taskId] = [...pending, ...additions];
      if (errorMap != null) {
        errorMap[taskId] = null;
      } else if (storage == null) {
        _commentErrors[taskId] = null;
      }
    });
    await _uploadPendingAttachments(
      taskId,
      storage: target,
      directoryBuilder: directoryBuilder,
      uploadContext: uploadContext,
    );
  }

  Future<_PendingCommentAttachment?> _pickRecentScan() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
      final recent = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .where((file) => file.statSync().modified.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      if (recent.isEmpty) return null;

      final chosen = await _showRecentScanPicker(recent);
      if (chosen == null) return null;

      final stat = chosen.statSync();
      final contentType = lookupMimeType(chosen.path) ?? 'application/pdf';
      final mediaType = contentType.startsWith('image/') ? 'image' : 'file';
      final normalizedName =
          _normalizeFilename(_stripDupSuffix(p.basename(chosen.path)), contentType);
      return _PendingCommentAttachment(
        file: chosen,
        name: normalizedName,
        length: stat.size,
        contentType: contentType,
        mediaType: mediaType,
        status: _AttachmentUploadStatus.queued,
        progress: 0,
      );
    } catch (e, st) {
      _log.warning('Error suggesting recent scan', e, st);
      return null;
    }
  }

  String _stripDupSuffix(String name) {
    final match = RegExp(r'^(.*)__dup\d+(\.[A-Za-z0-9]+)$').firstMatch(name);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}';
    }
    return name;
  }

  Future<File?> _showRecentScanPicker(List<File> files) {
    final items = files.take(5).toList();
    final now = DateTime.now();

    if (Platform.isIOS) {
      return showCupertinoModalPopup<File>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Недавние сканы'),
          actions: items
              .map(
                (file) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, file),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _stripDupSuffix(p.basename(file.path)),
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelative(now, file.statSync().modified),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Другое...'),
          ),
        ),
      );
    }

    return showModalBottomSheet<File>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Недавние сканы',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...items.map(
              (file) => ListTile(
                title: Text(
                  _stripDupSuffix(p.basename(file.path)),
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatRelative(now, file.statSync().modified),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                onTap: () => Navigator.pop(context, file),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.white),
              title: const Text('Выбрать другой файл', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelative(DateTime now, DateTime time) {
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'менее минуты назад';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return DateFormat('dd.MM.yyyy HH:mm').format(time);
  }

  void _removePendingAttachment(
    int taskId,
    int index, {
    Map<int, List<_PendingCommentAttachment>>? storage,
  }) {
    final target = storage ?? _pendingCommentAttachments;
    final pending = target[taskId];
    if (pending == null || pending.isEmpty) return;
    setState(() {
      final updated = [...pending]..removeAt(index);
      if (updated.isEmpty) {
        target.remove(taskId);
      } else {
        target[taskId] = updated;
      }
    });
  }

  void _updatePendingAttachment(
    int taskId,
    int index,
    _PendingCommentAttachment updated, {
    Map<int, List<_PendingCommentAttachment>>? storage,
  }) {
    final target = storage ?? _pendingCommentAttachments;
    final pending = target[taskId];
    if (pending == null || index >= pending.length) return;
    setState(() {
      final next = [...pending];
      next[index] = updated;
      target[taskId] = next;
    });
  }

  bool _isAttachmentReady(_PendingCommentAttachment item) {
    final hasUploadInfo =
        item.uploadedFilename != null && item.uploadedVersion != null;
    if (!hasUploadInfo) return false;
    final ready = item.progress >= 1 ||
        item.status == _AttachmentUploadStatus.uploaded ||
        (item.status == _AttachmentUploadStatus.uploading && item.progress >= 1);
    _log.fine(
      'Attachment readiness: name=${item.name} status=${item.status} '
      'progress=${item.progress.toStringAsFixed(3)} ready=$ready '
      'hasUploadInfo=$hasUploadInfo',
    );
    return ready;
  }

  Future<void> _uploadPendingAttachments(
    int taskId, {
    Map<int, List<_PendingCommentAttachment>>? storage,
    String Function(int taskId)? directoryBuilder,
    String uploadContext = 'comment',
  }) async {
    final target = storage ?? _pendingCommentAttachments;
    final buildDirectory =
        directoryBuilder ?? (id) => 'tasks/$id/comments/${const Uuid().v4()}';
    var i = 0;
    while (true) {
      final pending = target[taskId];
      if (pending == null || i >= pending.length) return;
      final item = pending[i];
      _log.info(
        'Upload start [$uploadContext]: taskId=$taskId index=$i name=${item.name} '
        'status=${item.status} progress=${item.progress.toStringAsFixed(3)}',
      );
      if (item.status == _AttachmentUploadStatus.uploaded ||
          item.status == _AttachmentUploadStatus.uploading) {
        i++;
        continue;
      }
      _updatePendingAttachment(
        taskId,
        i,
        item.copyWith(
          status: _AttachmentUploadStatus.uploading,
          progress: 0,
          error: null,
        ),
        storage: target,
      );
      final directory = buildDirectory(taskId);
      _log.info(
        'Request upload link [$uploadContext]: taskId=$taskId index=$i name=${item.name} '
        'contentType=${item.contentType} directory=$directory',
      );
      final link = await apiService.getUploadLink(
        directory: directory,
        filename: item.name,
        contentType: item.contentType,
      );
      if (link == null) {
        _log.warning(
          'Upload link failed: taskId=$taskId index=$i name=${item.name}',
        );
        _updatePendingAttachment(
          taskId,
          i,
          item.copyWith(
            status: _AttachmentUploadStatus.failed,
            error: 'Не удалось получить ссылку',
          ),
          storage: target,
        );
        i++;
        continue;
      }
      _log.info(
        'Upload link ok [$uploadContext]: taskId=$taskId index=$i name=${item.name} '
        'filename=${link.filename} version=${link.version}',
      );
      final currentForLink = target[taskId];
      if (currentForLink == null || i >= currentForLink.length) return;
      _updatePendingAttachment(
        taskId,
        i,
        currentForLink[i].copyWith(
          uploadedFilename: link.filename,
          uploadedVersion: link.version,
          uploadedShortName: link.shortName,
          uploadedObjectKey: link.objectKey,
          status: _AttachmentUploadStatus.uploading,
        ),
        storage: target,
      );
      _log.info(
        'Upload PUT call [$uploadContext]: taskId=$taskId index=$i url=${link.url}',
      );
      final uploaded = await apiService.uploadFileToUrlWithProgress(
        url: link.url,
        file: item.file,
        contentType: item.contentType,
        metaVersion: link.version,
        onProgress: (progress) {
          if (!mounted) return;
          _log.fine(
            'Upload progress [$uploadContext]: taskId=$taskId index=$i name=${item.name} '
            'progress=${progress.toStringAsFixed(3)}',
          );
          final current = target[taskId];
          if (current == null || i >= current.length) return;
          _updatePendingAttachment(
            taskId,
            i,
            current[i].copyWith(progress: progress),
            storage: target,
          );
        },
      );
      if (!uploaded) {
        _log.warning(
          'Upload failed [$uploadContext]: taskId=$taskId index=$i name=${item.name}',
        );
        _updatePendingAttachment(
          taskId,
          i,
          item.copyWith(
            status: _AttachmentUploadStatus.failed,
            error: 'Ошибка загрузки',
          ),
          storage: target,
        );
        i++;
        continue;
      }
      _log.info(
        'Upload success [$uploadContext]: taskId=$taskId index=$i name=${item.name}',
      );
      final current = target[taskId];
      if (current == null || i >= current.length) return;
      _updatePendingAttachment(
        taskId,
        i,
        current[i].copyWith(
          status: _AttachmentUploadStatus.uploaded,
          progress: 1,
          uploadedFilename: link.filename,
          uploadedVersion: link.version,
        ),
        storage: target,
      );
      i++;
    }
  }

  String _normalizeFilename(String name, String contentType) {
    var normalized = name.trim();
    final suffixMatch =
        RegExp(r'^(.*\.[A-Za-z0-9]+)_[A-Za-z0-9]{4,}$').firstMatch(normalized);
    if (suffixMatch != null) {
      normalized = suffixMatch.group(1) ?? normalized;
    }
    final dupMatch = RegExp(r'^(.*)__dup\d+(\.[A-Za-z0-9]+)$').firstMatch(normalized);
    if (dupMatch != null) {
      normalized = '${dupMatch.group(1)}${dupMatch.group(2)}';
    }
    final currentExt = p.extension(normalized);
    if (currentExt.isNotEmpty) {
      final base = p.basenameWithoutExtension(normalized);
      normalized = '$base${currentExt.toLowerCase()}';
    } else {
      final ext = extensionFromMime(contentType);
      if (ext != null && ext.isNotEmpty) {
        normalized = '$normalized.$ext';
      }
    }
    return normalized;
  }

  Future<void> _submitComment(int taskId) async {
    final controller = _commentControllerFor(taskId);
    final rawText = controller.text.trim();
    final pending = _pendingCommentAttachments[taskId] ?? [];
    _log.info(
      'Submit comment: taskId=$taskId rawTextLen=${rawText.length} '
      'pending=${pending.length}',
    );
    if (rawText.isEmpty && pending.isEmpty) {
      setState(() => _commentErrors[taskId] = 'Введите текст комментария');
      return;
    }
    if (pending.any((item) => item.status == _AttachmentUploadStatus.uploading && item.progress < 1)) {
      setState(() => _commentErrors[taskId] = 'Дождитесь загрузки файлов');
      return;
    }
    if (pending.any((item) => item.status == _AttachmentUploadStatus.failed)) {
      setState(() => _commentErrors[taskId] = 'Не все файлы загрузились');
      return;
    }
    final attachments = pending
        .where(_isAttachmentReady)
        .map((item) => {
              'version': item.uploadedVersion,
              'filename': item.uploadedFilename ?? item.uploadedObjectKey,
              'length': item.length,
              'mediaType': item.mediaType,
              'name': _attachmentNameFor(item),
            })
        .toList();
    _log.info(
      'Submit comment attachments: taskId=$taskId count=${attachments.length}',
    );
    _log.fine(
      'Submit comment attachments payload: taskId=$taskId ${jsonEncode(attachments)}',
    );
    if (rawText.isEmpty && attachments.isEmpty) {
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
        attachments: attachments,
      );
      if (!mounted) return;
      if (commentId == null) {
        setState(() => _commentErrors[taskId] = 'Не удалось отправить комментарий');
        return;
      }
      controller.clear();
      setState(() => _pendingCommentAttachments.remove(taskId));
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

  Future<void> _submitSolution(int taskId) async {
    final controller = _solutionUrlControllerFor(taskId);
    final rawUrl = controller.text.trim();
    final pending = _pendingSolutionAttachments[taskId] ?? [];
    final details = _taskDetailsById[taskId];
    final existing = _editingSolutionAttachments[taskId] ??
        details?.solutionAttachments ??
        const <MaterialAttachment>[];
    _log.info(
      'Submit solution: taskId=$taskId urlLen=${rawUrl.length} pending=${pending.length} existing=${existing.length}',
    );

    if (pending.any(
      (item) => item.status == _AttachmentUploadStatus.uploading && item.progress < 1,
    )) {
      setState(() => _solutionErrors[taskId] = 'Дождитесь загрузки файлов');
      return;
    }
    if (pending.any((item) => item.status == _AttachmentUploadStatus.failed)) {
      setState(() => _solutionErrors[taskId] = 'Не все файлы загрузились');
      return;
    }

    final hasUrl = rawUrl.isNotEmpty;
    if (hasUrl && !_isValidUrl(rawUrl)) {
      setState(() => _solutionErrors[taskId] = 'Введите корректную ссылку');
      return;
    }

    final attachments = pending
        .where(_isAttachmentReady)
        .map((item) => {
              'version': item.uploadedVersion,
              'filename': item.uploadedFilename ?? item.uploadedObjectKey,
              'length': item.length,
              'mediaType': item.mediaType,
              'name': _attachmentNameFor(item),
            })
        .toList()
      ..addAll(existing.map(
        (item) => {
              'version': item.version,
              'filename': item.filename,
              'length': item.length,
              'mediaType': item.mediaType,
              'name': item.name,
            },
      ));

    if (!hasUrl && attachments.isEmpty) {
      setState(() => _solutionErrors[taskId] = 'Добавьте ссылку или файлы');
      return;
    }

    setState(() {
      _sendingSolutionTaskIds.add(taskId);
      _solutionErrors[taskId] = null;
    });

    try {
      final success = await apiService.submitTaskSolution(
        taskId: taskId,
        solutionUrl: hasUrl ? rawUrl : null,
        attachments: attachments,
      );
      if (!mounted) return;
      if (!success) {
        setState(() => _solutionErrors[taskId] = 'Не удалось отправить решение');
        return;
      }
      controller.clear();
      setState(() {
        _pendingSolutionAttachments.remove(taskId);
        _editingSolutionAttachments.remove(taskId);
        _isEditingSolution[taskId] = false;
        _solutionErrors[taskId] = null;
      });
      await _reloadTaskDetails(taskId);
    } catch (e, st) {
      _log.warning('Error sending solution', e, st);
      if (mounted) {
        setState(() => _solutionErrors[taskId] = 'Не удалось отправить решение');
      }
    } finally {
      if (mounted) {
        setState(() => _sendingSolutionTaskIds.remove(taskId));
      } else {
        _sendingSolutionTaskIds.remove(taskId);
      }
    }
  }

  bool _isValidUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  String _commentTextToHtml(String text) {
    if (text.trim().isEmpty) return '';
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(text);
    return '<p>${escaped.replaceAll('\n', '<br>')}</p>';
  }

  String _attachmentNameFor(_PendingCommentAttachment item) {
    final filename = item.uploadedFilename;
    if (filename != null && filename.isNotEmpty) {
      return p.basename(filename);
    }
    return item.uploadedShortName ?? item.name;
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
    final taskDetails =
        material.taskId != null ? _taskDetailsById[material.taskId!] : null;
    final scoreText = _formatScore(
      events,
      eventEstimation?.maxScore,
      materialEstimation?.maxScore,
      taskDetails,
    );
    final extraScoreText = taskDetails?.extraScore != null
        ? _formatScoreValue(taskDetails!.extraScore!)
        : '-';
    final status = _deriveStatus(events, taskDetails);

    return Column(
      children: [
        _buildInfoRow('Дедлайн', _formatDateTime(deadline)),
        _buildInfoRow('Статус', status),
        _buildInfoRow('Тип активности', activityName ?? '-'),
        _buildInfoRow('Название курса', widget.courseName ?? '-'),
        _buildInfoRow('Тема', widget.themeName ?? '-'),
        _buildInfoRow('Оценка', scoreText),
        _buildInfoRow('Дополнительный балл', extraScoreText),
      ],
    );
  }

  Widget _buildTaskSummary(LongreadMaterial material) {
    final taskId = material.taskId!;
    final events = _eventsByTaskId[taskId] ?? [];
    final details = _taskDetailsById[taskId];
    final isLoading = _loadingTaskIds.contains(taskId) && details == null && events.isEmpty;

    final levelIndex = details?.scoreSkillLevel;
    final levelText = _scoreLevelLabel(levelIndex);
    final scoreText = isLoading
        ? '-'
        : _formatScore(
            events,
            details?.maxScore,
            material.estimation?.maxScore,
            details,
          );
    final extraScoreText = details?.extraScore != null
        ? _formatScoreValue(details!.extraScore!)
        : '-';
    final statusText = _deriveStatus(events, details);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(
            'Уровень',
            Row(
              children: [
                _buildLevelIcon(1, levelIndex),
                const SizedBox(width: 8),
                _buildLevelIcon(2, levelIndex),
                const SizedBox(width: 8),
                _buildLevelIcon(3, levelIndex),
                const SizedBox(width: 12),
                Text(
                  levelText,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('Оценка', Text(scoreText, style: _summaryValueStyle)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Доп. балл',
            Text(extraScoreText, style: _summaryValueStyle),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('Статус', Text(statusText, style: _summaryValueStyle)),
        ],
      ),
    );
  }

  static const TextStyle _summaryValueStyle =
      TextStyle(fontSize: 12, color: Colors.white);

  Widget _buildSummaryRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }

  Widget _buildLevelIcon(int level, int? selectedLevel) {
    final isSelected = selectedLevel == level;
    final color = _scoreLevelColor(level);
    const defaultColor = Colors.white;
    final asset = switch (level) {
      1 => 'assets/icons/level-basic.svg',
      2 => 'assets/icons/level-medium.svg',
      _ => 'assets/icons/level-advanced.svg',
    };
    return SvgPicture.asset(
      asset,
      width: 18,
      height: 18,
      colorFilter: ColorFilter.mode(
        isSelected ? color : defaultColor,
        BlendMode.srcIn,
      ),
    );
  }

  String _scoreLevelLabel(int? level) {
    switch (level) {
      case 1:
        return 'Базовый';
      case 2:
        return 'Средний';
      case 3:
        return 'Продвинутый';
      default:
        return 'Без уровня';
    }
  }

  Color _scoreLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF3044FF);
      case 2:
        return const Color(0xFFE63F07);
      default:
        return const Color(0xFF141414);
    }
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
    final valueText = value != null ? _formatScoreValue(value) : '-';
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
        return value != null
            ? 'Задание принято на ${_formatScoreValue(value)} баллов'
            : '';
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
        apiService.fetchTaskDetails(taskId),
      ]);
      if (!mounted) return;
      setState(() {
        _eventsByTaskId[taskId] = results[0] as List<TaskEvent>;
        _commentsByTaskId[taskId] = results[1] as List<TaskComment>;
        final details = results[2] as TaskDetails?;
        if (details != null) {
          _taskDetailsById[taskId] = details;
        }
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

  String _formatScore(
    List<TaskEvent> events,
    int? maxScore,
    int? fallbackMax,
    TaskDetails? details,
  ) {
    double? value = details?.score;
    DateTime? latest;
    if (value == null) {
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
    }
    if (value == null) return '-';
    final max = details?.maxScore ?? maxScore ?? fallbackMax;
    final valueText = _formatScoreValue(value);
    return max != null ? '$valueText/$max' : valueText;
  }

  String _formatScoreValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _deriveStatus(List<TaskEvent> events, TaskDetails? details) {
    final state = details?.state;
    final submitAt = details?.submitAt;
    final hasSubmittedSolution = submitAt != null;
    if (state != null) {
      switch (state) {
        case 'evaluated':
          return 'Проверено';
        case 'backlog':
          return 'Бэклог';
        case 'inProgress':
          return hasSubmittedSolution ? 'Есть решение' : 'В работе';
        case 'review':
          return 'На проверке';
        case 'revision':
        case 'rework':
          return 'Дорешивание';
        case 'failed':
        case 'rejected':
          return 'Не сдано';
      }
    }
    if (hasSubmittedSolution) return 'Есть решение';
    final types = events.map((e) => e.type).toSet();
    if (types.contains('taskEvaluated')) return 'Проверено';
    if (types.contains('taskCompleted') || events.any((e) => e.content.state == 'review')) {
      return 'На проверке';
    }
    if (submitAt != null && types.contains('solutionAttached')) return 'Есть решение';
    if (types.contains('taskStarted')) return 'В работе';
    return 'Не сдано';
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

enum _AttachmentUploadStatus { queued, uploading, uploaded, failed }

class _PendingCommentAttachment {
  final File file;
  final String name;
  final int length;
  final String contentType;
  final String mediaType;
  final _AttachmentUploadStatus status;
  final double progress;
  final String? uploadedFilename;
  final String? uploadedVersion;
  final String? uploadedShortName;
  final String? uploadedObjectKey;
  final String? error;

  const _PendingCommentAttachment({
    required this.file,
    required this.name,
    required this.length,
    required this.contentType,
    required this.mediaType,
    required this.status,
    required this.progress,
    this.uploadedFilename,
    this.uploadedVersion,
    this.uploadedShortName,
    this.uploadedObjectKey,
    this.error,
  });

  _PendingCommentAttachment copyWith({
    _AttachmentUploadStatus? status,
    double? progress,
    String? uploadedFilename,
    String? uploadedVersion,
    String? uploadedShortName,
    String? uploadedObjectKey,
    String? error,
  }) {
    return _PendingCommentAttachment(
      file: file,
      name: name,
      length: length,
      contentType: contentType,
      mediaType: mediaType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      uploadedFilename: uploadedFilename ?? this.uploadedFilename,
      uploadedVersion: uploadedVersion ?? this.uploadedVersion,
      uploadedShortName: uploadedShortName ?? this.uploadedShortName,
      uploadedObjectKey: uploadedObjectKey ?? this.uploadedObjectKey,
      error: error ?? this.error,
    );
  }
}
