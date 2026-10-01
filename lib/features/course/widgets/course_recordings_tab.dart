import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/core/ui/app_dialogs.dart';
import 'package:cumobile/data/models/course_extras.dart';
import 'package:cumobile/data/services/api_service.dart';

enum _DatePreset { any, today, yesterday, thisWeek, lastWeek, lastMonth, custom }

class CourseRecordingsTab extends StatefulWidget {
  final int courseId;
  final Color themeColor;

  const CourseRecordingsTab({
    super.key,
    required this.courseId,
    required this.themeColor,
  });

  @override
  State<CourseRecordingsTab> createState() => _CourseRecordingsTabState();
}

class _CourseRecordingsTabState extends State<CourseRecordingsTab>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 100;

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy, EE', 'ru_RU');
  final DateFormat _shortDateFormat = DateFormat('dd.MM.yyyy', 'ru_RU');

  List<RecordingHost> _hosts = [];
  List<RecordingEvent> _events = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _requestId = 0;

  bool _myEvents = true;
  Set<String> _types = {'seminar', 'lecture'};
  Set<String> _hostKeys = {};
  _DatePreset _datePreset = _DatePreset.any;
  DateTime? _customDate;

  final Set<String> _openingKeys = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHosts();
    _load();
  }

  Future<void> _loadHosts() async {
    final hosts = await apiService.fetchRecordingHosts(widget.courseId);
    if (!mounted) return;
    setState(() => _hosts = hosts);
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final selectedHosts = _hosts.where((h) => _hostKeys.contains(h.key)).toList();
    final includesNoHost = selectedHosts.any((h) => h.isNoHost);
    final serverEmails = includesNoHost
        ? const <String>[]
        : selectedHosts.map((h) => h.email).whereType<String>().toList();

    final all = <RecordingEvent>[];
    var offset = 0;
    var failed = false;
    while (true) {
      final page = await apiService.fetchRecordingEvents(
        courseId: widget.courseId,
        offset: offset,
        limit: _pageSize,
        myEvents: _myEvents,
        eventTypes: _types.isEmpty ? recordingEventTypes.keys : _types,
        hostEmails: serverEmails,
      );
      if (!mounted || requestId != _requestId) return;
      if (page == null) {
        failed = true;
        break;
      }
      all.addAll(page.items);
      offset += page.items.length;
      if (page.items.isEmpty || offset >= page.totalCount) break;
    }

    var events = all;
    if (includesNoHost) {
      final emails = selectedHosts.map((h) => h.email).whereType<String>().toSet();
      events = events
          .where((e) => e.hosts.isEmpty || e.hosts.any((h) => emails.contains(h.email)))
          .toList();
    }

    setState(() {
      _isLoading = false;
      _hasError = failed && all.isEmpty;
      _events = events;
    });
  }

  (DateTime, DateTime)? _dateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_datePreset) {
      case _DatePreset.any:
        return null;
      case _DatePreset.today:
        return (today, today);
      case _DatePreset.yesterday:
        final d = today.subtract(const Duration(days: 1));
        return (d, d);
      case _DatePreset.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (start, start.add(const Duration(days: 6)));
      case _DatePreset.lastWeek:
        final start = today.subtract(Duration(days: today.weekday - 1 + 7));
        return (start, start.add(const Duration(days: 6)));
      case _DatePreset.lastMonth:
        final start = DateTime(today.year, today.month - 1, 1);
        final end = DateTime(today.year, today.month, 0);
        return (start, end);
      case _DatePreset.custom:
        final d = _customDate;
        if (d == null) return null;
        return (d, d);
    }
  }

  List<RecordingEvent> get _visibleEvents {
    final range = _dateRange();
    if (range == null) return _events;
    return _events.where((e) {
      final date = e.date;
      if (date == null) return false;
      return !date.isBefore(range.$1) && !date.isAfter(range.$2);
    }).toList();
  }

  String get _dateLabel {
    switch (_datePreset) {
      case _DatePreset.any:
        return 'Дата';
      case _DatePreset.today:
        return 'Сегодня';
      case _DatePreset.yesterday:
        return 'Вчера';
      case _DatePreset.thisWeek:
        return 'Текущая неделя';
      case _DatePreset.lastWeek:
        return 'Прошлая неделя';
      case _DatePreset.lastMonth:
        return 'Прошлый месяц';
      case _DatePreset.custom:
        final d = _customDate;
        return d == null ? 'Дата' : _shortDateFormat.format(d);
    }
  }

  String get _typesLabel {
    if (_types.isEmpty || _types.length == recordingEventTypes.length) return 'Тип события';
    final first = recordingEventTypes[_types.first] ?? _types.first;
    return _types.length == 1 ? first : '$first +${_types.length - 1}';
  }

  String get _hostsLabel {
    if (_hostKeys.isEmpty) return 'Преподаватель';
    final first = _hosts.firstWhere(
      (h) => _hostKeys.contains(h.key),
      orElse: () => const RecordingHost(name: 'Преподаватель'),
    );
    return _hostKeys.length == 1
        ? first.displayName
        : '${first.displayName} +${_hostKeys.length - 1}';
  }

  Future<void> _pickDatePreset() async {
    const presets = [
      (_DatePreset.any, 'Любая дата'),
      (_DatePreset.today, 'Сегодня'),
      (_DatePreset.yesterday, 'Вчера'),
      (_DatePreset.thisWeek, 'Текущая неделя'),
      (_DatePreset.lastWeek, 'Прошлая неделя'),
      (_DatePreset.lastMonth, 'Прошлый месяц'),
      (_DatePreset.custom, 'Другая дата…'),
    ];
    final selected = await _showOptionsSheet<_DatePreset>(
      title: 'Дата',
      options: presets,
      current: _datePreset,
    );
    if (selected == null || !mounted) return;
    if (selected == _DatePreset.custom) {
      final now = DateTime.now();
      final picked = await AppDialogs.pickDate(
        context,
        initial: _customDate ?? now,
        minimum: now.subtract(const Duration(days: 730)),
        maximum: now,
        title: 'Дата записи',
      );
      if (picked == null || !mounted) return;
      setState(() {
        _datePreset = _DatePreset.custom;
        _customDate = DateTime(picked.year, picked.month, picked.day);
      });
      return;
    }
    setState(() => _datePreset = selected);
  }

  Future<T?> _showOptionsSheet<T>({
    required String title,
    required List<(T, String)> options,
    required T current,
  }) {
    final c = AppColors.of(context);
    if (Platform.isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(title),
          actions: options
              .map(
                (o) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(ctx, o.$1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(o.$2),
                      if (o.$1 == current) ...[
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.check_mark, size: 16),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ),
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: c.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (o) => ListTile(
                  title: Text(o.$2, style: TextStyle(color: c.textPrimary)),
                  trailing: o.$1 == current ? Icon(Icons.check, color: c.accent) : null,
                  onTap: () => Navigator.pop(ctx, o.$1),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<Set<String>?> _showMultiSelect({
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
  }) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final draft = {...selected};
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(draft.clear),
                          child: Text('Сбросить', style: TextStyle(color: c.textTertiary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, draft),
                          child: Text(
                            'Готово',
                            style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: options.map((o) {
                        final checked = draft.contains(o.$1);
                        return ListTile(
                          dense: true,
                          title: Text(o.$2, style: TextStyle(color: c.textPrimary)),
                          trailing: Icon(
                            checked
                                ? (isIos
                                    ? CupertinoIcons.checkmark_square_fill
                                    : Icons.check_box)
                                : (isIos
                                    ? CupertinoIcons.square
                                    : Icons.check_box_outline_blank),
                            color: checked ? c.accent : c.textTertiary,
                          ),
                          onTap: () => setSheetState(() {
                            if (!draft.remove(o.$1)) draft.add(o.$1);
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTypes() async {
    final result = await _showMultiSelect(
      title: 'Тип события',
      options: recordingEventTypes.entries.map((e) => (e.key, e.value)).toList(),
      selected: _types,
    );
    if (result == null || !mounted) return;
    setState(() => _types = result);
    _load();
  }

  Future<void> _pickHosts() async {
    if (_hosts.isEmpty) await _loadHosts();
    if (!mounted) return;
    final result = await _showMultiSelect(
      title: 'Преподаватель',
      options: _hosts.map((h) => (h.key, h.displayName)).toList(),
      selected: _hostKeys,
    );
    if (result == null || !mounted) return;
    setState(() => _hostKeys = result);
    _load();
  }

  Future<void> _openRecording(RecordingEvent event) async {
    final key = '${event.id}_${event.actualDate}';
    if (_openingKeys.contains(key)) return;
    setState(() => _openingKeys.add(key));
    final recordings = await apiService.fetchEventRecordings(event.id, event.actualDate);
    if (!mounted) return;
    setState(() => _openingKeys.remove(key));

    if (recordings == null) {
      _showMessage('Не удалось загрузить запись');
      return;
    }
    if (recordings.isEmpty) {
      _showMessage('Запись пока недоступна');
      return;
    }
    if (recordings.length == 1) {
      await _launch(recordings.first.url);
      return;
    }
    await _showRecordingsSheet(event, recordings);
  }

  Future<void> _showRecordingsSheet(RecordingEvent event, List<EventRecording> recordings) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                event.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
            ...recordings.map(
              (r) => ListTile(
                leading: Icon(
                  isIos ? CupertinoIcons.videocam : Icons.videocam_outlined,
                  color: c.accent,
                ),
                title: Text('Видеозапись', style: TextStyle(color: c.textPrimary)),
                subtitle: Text(
                  r.formattedDuration,
                  style: TextStyle(color: c.textTertiary),
                ),
                trailing: Icon(
                  isIos ? CupertinoIcons.arrow_up_right_square : Icons.open_in_new,
                  color: c.textTertiary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _launch(r.url);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Не удалось открыть ссылку');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    if (Platform.isIOS) {
      AppDialogs.message(context, message: text);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIos = Platform.isIOS;
    return Column(
      children: [
        _buildFilters(isIos),
        Expanded(child: _buildList(isIos)),
      ],
    );
  }

  Widget _buildFilters(bool isIos) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _buildChip(
            label: 'Мои пары',
            active: _myEvents,
            icon: _myEvents
                ? (isIos ? CupertinoIcons.checkmark_alt : Icons.check)
                : null,
            onTap: () {
              setState(() => _myEvents = !_myEvents);
              _load();
            },
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: _dateLabel,
            active: _datePreset != _DatePreset.any,
            icon: isIos ? CupertinoIcons.chevron_down : Icons.expand_more,
            onTap: _pickDatePreset,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: _hostsLabel,
            active: _hostKeys.isNotEmpty,
            icon: isIos ? CupertinoIcons.chevron_down : Icons.expand_more,
            onTap: _pickHosts,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: _typesLabel,
            active: _types.isNotEmpty && _types.length != recordingEventTypes.length,
            icon: isIos ? CupertinoIcons.chevron_down : Icons.expand_more,
            onTap: _pickTypes,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final c = AppColors.of(context);
    final color = active ? c.accent : c.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? c.accent.withValues(alpha: 0.6) : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: color),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(bool isIos) {
    final c = AppColors.of(context);
    if (_isLoading) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(radius: 14, color: c.accent)
            : CircularProgressIndicator(color: c.accent),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Не удалось загрузить записи', style: TextStyle(color: c.textTertiary)),
            const SizedBox(height: 12),
            isIos
                ? CupertinoButton(onPressed: _load, child: const Text('Повторить'))
                : TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final events = _visibleEvents;
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIos ? CupertinoIcons.videocam : Icons.videocam_off_outlined,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text('Записей нет', style: TextStyle(color: c.textTertiary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
      itemCount: events.length,
      itemBuilder: (context, index) => _buildEventCard(events[index], isIos),
    );
  }

  Widget _buildEventCard(RecordingEvent event, bool isIos) {
    final c = AppColors.of(context);
    final date = event.date;
    final isOpening = _openingKeys.contains('${event.id}_${event.actualDate}');
    final hosts = event.hosts.map((h) => h.displayName).join(', ');

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.themeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isOpening
                  ? (isIos
                      ? CupertinoActivityIndicator(radius: 9, color: widget.themeColor)
                      : SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.themeColor,
                          ),
                        ))
                  : Icon(
                      isIos ? CupertinoIcons.play_rectangle_fill : Icons.play_circle_fill,
                      size: 20,
                      color: widget.themeColor,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.typeLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (date != null) _dateFormat.format(date),
                    '${event.startTime} – ${event.endTime}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                if (hosts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    hosts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isIos ? CupertinoIcons.arrow_up_right_square : Icons.open_in_new,
            size: 18,
            color: c.textTertiary,
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isIos
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openRecording(event),
              child: content,
            )
          : InkWell(
              onTap: () => _openRecording(event),
              borderRadius: BorderRadius.circular(12),
              child: content,
            ),
    );
  }
}
