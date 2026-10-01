import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/attendance.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/attendance/pages/attendance_course_page.dart';

class AttendanceTab extends StatefulWidget {
  final double bottomInset;
  final bool showCampusMap;

  const AttendanceTab({super.key, this.bottomInset = 0, this.showCampusMap = false});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  static const _availableColor = Color(0xFF4CAF50);
  static const _unavailableColor = Color(0xFFFF9800);

  bool _showArchived = false;
  final Map<bool, List<AttendanceCourse>> _coursesByArchive = {};
  final Set<bool> _loading = {};
  final Set<bool> _failed = {};

  @override
  void initState() {
    super.initState();
    _load(false);
  }

  Future<void> _load(bool archived) async {
    setState(() {
      _loading.add(archived);
      _failed.remove(archived);
    });
    final courses = await apiService.fetchAttendanceCourses(archived: archived);
    if (!mounted) return;
    setState(() {
      _loading.remove(archived);
      if (courses == null) {
        _failed.add(archived);
      } else {
        _coursesByArchive[archived] = _sorted(courses);
      }
    });
  }

  List<AttendanceCourse> _sorted(List<AttendanceCourse> courses) {
    final indexed = courses.asMap().entries.toList()
      ..sort((a, b) {
        final aVisible = a.value.isVisibleForStudents ? 0 : 1;
        final bVisible = b.value.isVisibleForStudents ? 0 : 1;
        if (aVisible != bVisible) return aVisible - bVisible;
        return a.key - b.key;
      });
    return indexed.map((e) => e.value).toList();
  }

  void _changeArchive(bool archived) {
    if (archived == _showArchived) return;
    setState(() => _showArchived = archived);
    if (!_coursesByArchive.containsKey(archived) && !_loading.contains(archived)) {
      _load(archived);
    }
  }

  void _openCourse(AttendanceCourse course) {
    final route = Platform.isIOS
        ? CupertinoPageRoute<void>(
            builder: (_) => AttendanceCoursePage(
              course: course,
              showCampusMap: widget.showCampusMap,
            ),
          )
        : MaterialPageRoute<void>(
            builder: (_) => AttendanceCoursePage(
              course: course,
              showCampusMap: widget.showCampusMap,
            ),
          );
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return Column(
      children: [
        _buildArchiveSwitch(isIos),
        Expanded(child: _buildContent(isIos)),
      ],
    );
  }

  Widget _buildArchiveSwitch(bool isIos) {
    final c = AppColors.of(context);
    Widget chip(bool archived, String label) {
      final selected = _showArchived == archived;
      return GestureDetector(
        onTap: () => _changeArchive(archived),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.2) : c.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? c.accent : c.textTertiary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chip(false, 'Актуальные'),
          const SizedBox(width: 8),
          chip(true, 'Архивные'),
        ],
      ),
    );
  }

  Widget _buildContent(bool isIos) {
    final c = AppColors.of(context);
    final archived = _showArchived;
    final courses = _coursesByArchive[archived];

    if (courses == null && _loading.contains(archived)) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(radius: 14, color: c.accent)
            : CircularProgressIndicator(color: c.accent),
      );
    }

    if (courses == null && _failed.contains(archived)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Не удалось загрузить посещаемость',
              style: TextStyle(color: c.textTertiary),
            ),
            const SizedBox(height: 12),
            isIos
                ? CupertinoButton(
                    onPressed: () => _load(archived),
                    child: const Text('Повторить'),
                  )
                : TextButton(
                    onPressed: () => _load(archived),
                    child: const Text('Повторить'),
                  ),
          ],
        ),
      );
    }

    final list = courses ?? const <AttendanceCourse>[];
    final children = <Widget>[
      _buildNotice(isIos),
      const SizedBox(height: 12),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            children: [
              Icon(
                isIos ? CupertinoIcons.person_crop_circle_badge_checkmark : Icons.how_to_reg,
                size: 48,
                color: c.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                archived ? 'Нет архивных курсов' : 'Нет курсов',
                style: TextStyle(color: c.textTertiary, fontSize: 16),
              ),
            ],
          ),
        )
      else
        ...list.map((course) => _buildCourseTile(course, isIos)),
    ];

    if (isIos) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _load(archived)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + widget.bottomInset),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: c.accent,
      onRefresh: () => _load(archived),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + widget.bottomInset),
        children: children,
      ),
    );
  }

  Widget _buildNotice(bool isIos) {
    final c = AppColors.of(context);
    const color = Color(0xFFFFCA28);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isIos ? CupertinoIcons.exclamationmark_triangle_fill : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Если посещение не отобразилось спустя неделю после пары — свяжись с поддержкой в Маяке',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTile(AttendanceCourse course, bool isIos) {
    final c = AppColors.of(context);
    final available = course.isVisibleForStudents;
    final badgeColor = available ? _availableColor : _unavailableColor;
    final stats = course.stats;

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildPercentBadge(stats, available),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.cleanName,
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        course.studentStatusLabel,
                        style: TextStyle(fontSize: 12, color: c.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        available ? 'Доступна' : 'Недоступна',
                        style: TextStyle(fontSize: 11, color: badgeColor),
                      ),
                    ),
                  ],
                ),
                if (stats != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'За семестр: ${stats.attendedCount} из ${stats.enrolledCount}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
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
              onTap: () => _openCourse(course),
              child: content,
            )
          : InkWell(
              onTap: () => _openCourse(course),
              borderRadius: BorderRadius.circular(12),
              child: content,
            ),
    );
  }

  Widget _buildPercentBadge(AttendanceStats? stats, bool available) {
    final c = AppColors.of(context);
    final color = stats == null ? c.textTertiary : _percentColor(stats.percent);
    return Container(
      width: 56,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          stats == null ? '—' : '${stats.percent.round()}%',
          style: TextStyle(
            fontSize: stats == null ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Color _percentColor(double percent) {
    if (percent >= 75) return const Color(0xFF4CAF50);
    if (percent >= 50) return const Color(0xFFFFCA28);
    if (percent >= 25) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }
}
