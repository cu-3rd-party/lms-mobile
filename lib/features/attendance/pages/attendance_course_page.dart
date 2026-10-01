import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/core/ui/app_dialogs.dart';
import 'package:cumobile/data/models/attendance.dart';
import 'package:cumobile/data/services/api_service.dart';

class AttendanceCoursePage extends StatefulWidget {
  final AttendanceCourse course;

  const AttendanceCoursePage({super.key, required this.course});

  @override
  State<AttendanceCoursePage> createState() => _AttendanceCoursePageState();
}

enum _AttendanceMark { attended, missed, upcoming }

class _AttendanceCoursePageState extends State<AttendanceCoursePage> {
  static const _attendedColor = Color(0xFF4CAF50);
  static const _missedColor = Color(0xFFEF5350);

  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _titleDateFormat = DateFormat('d MMMM, EEEE', 'ru_RU');
  final DateFormat _shortDateFormat = DateFormat('dd.MM.yyyy', 'ru_RU');

  late DateTime _date;
  List<AttendanceEvent> _events = [];
  Set<String> _attendedIds = {};
  bool _isLoading = true;
  bool _hasError = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    final date = _apiDateFormat.format(_date);
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final results = await Future.wait([
      apiService.fetchCourseEventsByDate(widget.course.courseId, date),
      apiService.fetchAttendedEventIds(widget.course.courseId, date),
    ]);
    if (!mounted || requestId != _requestId) return;
    final events = results[0] as List<AttendanceEvent>?;
    final attended = results[1] as Set<String>?;
    setState(() {
      _isLoading = false;
      if (events == null) {
        _hasError = true;
        _events = [];
        _attendedIds = {};
        return;
      }
      _events = [...events]..sort((a, b) => a.startTime.compareTo(b.startTime));
      _attendedIds = attended ?? {};
    });
  }

  void _shiftDate(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
    _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await AppDialogs.pickDate(
      context,
      initial: _date,
      minimum: now.subtract(const Duration(days: 365)),
      maximum: now.add(const Duration(days: 365)),
      title: 'Дата',
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    if (day == _date) return;
    setState(() => _date = day);
    _load();
  }

  _AttendanceMark _markFor(AttendanceEvent event) {
    if (_attendedIds.contains(event.eventId)) return _AttendanceMark.attended;
    final end = event.endDateTime;
    if (end != null && end.isAfter(DateTime.now())) return _AttendanceMark.upcoming;
    return _AttendanceMark.missed;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final title = Text(
      widget.course.cleanName,
      style: TextStyle(color: c.textPrimary, fontSize: 16),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (isIos) {
      return CupertinoPageScaffold(
        backgroundColor: c.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: c.background,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(CupertinoIcons.back, color: c.accent),
          ),
          middle: title,
        ),
        child: SafeArea(bottom: false, child: _buildBody(isIos)),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: title,
      ),
      body: _buildBody(isIos),
    );
  }

  Widget _buildBody(bool isIos) {
    return Column(
      children: [
        _buildSummary(),
        _buildDateSelector(isIos),
        Expanded(child: _buildEvents(isIos)),
      ],
    );
  }

  Widget _buildSummary() {
    final c = AppColors.of(context);
    final stats = widget.course.stats;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статус',
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.course.studentStatusLabel,
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'За весь семестр',
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  stats?.summary ?? '—',
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isIos) {
    final c = AppColors.of(context);
    Widget arrow(IconData icon, int days) {
      return isIos
          ? CupertinoButton(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
              onPressed: () => _shiftDate(days),
              child: Icon(icon, size: 20, color: c.accent),
            )
          : IconButton(
              onPressed: () => _shiftDate(days),
              icon: Icon(icon, color: c.accent),
            );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          arrow(isIos ? CupertinoIcons.chevron_left : Icons.chevron_left, -1),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.accent.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIos ? CupertinoIcons.calendar : Icons.calendar_today,
                      size: 16,
                      color: c.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Дата: ${_shortDateFormat.format(_date)}',
                      style: TextStyle(fontSize: 14, color: c.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          arrow(isIos ? CupertinoIcons.chevron_right : Icons.chevron_right, 1),
        ],
      ),
    );
  }

  Widget _buildEvents(bool isIos) {
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
            Text(
              'Не удалось загрузить занятия',
              style: TextStyle(color: c.textTertiary),
            ),
            const SizedBox(height: 12),
            isIos
                ? CupertinoButton(onPressed: _load, child: const Text('Повторить'))
                : TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIos ? CupertinoIcons.calendar_badge_minus : Icons.event_busy,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'В этот день занятий нет',
              style: TextStyle(color: c.textTertiary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: _events.length,
      itemBuilder: (context, index) => _buildEventCard(_events[index], isIos),
    );
  }

  Widget _buildEventCard(AttendanceEvent event, bool isIos) {
    final c = AppColors.of(context);
    final mark = _markFor(event);
    final markColor = switch (mark) {
      _AttendanceMark.attended => _attendedColor,
      _AttendanceMark.missed => _missedColor,
      _AttendanceMark.upcoming => c.textTertiary,
    };
    final markLabel = switch (mark) {
      _AttendanceMark.attended => 'Был',
      _AttendanceMark.missed => 'Не был',
      _AttendanceMark.upcoming => 'Ожидается',
    };
    final date = DateTime.tryParse(event.actualDate);
    final location = [
      if (event.locationTitle?.isNotEmpty ?? false) event.locationTitle!,
      if (event.formatLabel.isNotEmpty) event.formatLabel,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: event.isParticipant
            ? Border.all(color: c.accent.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${event.startTime}–${event.endTime}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      event.typeLabel,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
                if (date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _titleDateFormat.format(date),
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                ],
                if (event.hostNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    event.hostNames,
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                  ),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                ],
                if (event.isParticipant) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isIos ? CupertinoIcons.bookmark_fill : Icons.bookmark,
                        size: 13,
                        color: c.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Вы записаны',
                        style: TextStyle(fontSize: 12, color: c.accent),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: markColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              markLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: markColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
