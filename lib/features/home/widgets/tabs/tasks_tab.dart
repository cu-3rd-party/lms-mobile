import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/data/models/student_task.dart';

const _statusLabels = <String, String>{
  'backlog': 'Не начато',
  'inProgress': 'В работе',
  'hasSolution': 'Есть решение',
  'revision': 'Доработка',
  'review': 'На проверке',
  'failed': 'Не сдано',
  'evaluated': 'Проверено',
};

class TasksTab extends StatefulWidget {
  final List<StudentTask> tasks;
  final bool isLoading;
  final Set<String> statusFilters;
  final void Function(Set<String>) onStatusFiltersChanged;
  final Set<int> courseFilters;
  final void Function(Set<int>) onCourseFiltersChanged;
  final String searchQuery;
  final void Function(String) onSearchQueryChanged;
  final void Function(StudentTask) onOpenTask;
  final Set<int> userArchivedCourseIds;
  final int lateDaysBalance;
  final void Function(StudentTask task)? onExtendDeadline;
  final void Function(StudentTask task)? onCancelLateDays;

  const TasksTab({
    super.key,
    required this.tasks,
    required this.isLoading,
    required this.statusFilters,
    required this.onStatusFiltersChanged,
    required this.courseFilters,
    required this.onCourseFiltersChanged,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.onOpenTask,
    this.userArchivedCourseIds = const {},
    this.lateDaysBalance = 0,
    this.onExtendDeadline,
    this.onCancelLateDays,
  });

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  static const _activeStates = {'backlog', 'inProgress', 'hasSolution', 'revision', 'rework', 'review'};
  static const _archiveStates = {'evaluated', 'failed', 'rejected'};

  // Display keys: rework → revision, rejected → failed
  static const _displayStatesActive = {'backlog', 'inProgress', 'hasSolution', 'revision', 'review'};
  static const _displayStatesArchive = {'evaluated', 'failed'};

  static String _normalizeForDisplay(String state) {
    if (state == 'rework') return 'revision';
    if (state == 'rejected') return 'failed';
    return state;
  }

  int _segment = 0; // 0 = active, 1 = archive

  bool get _isActive => _segment == 0;

  Set<String> get _statesForSegment => _isActive ? _activeStates : _archiveStates;

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    if (widget.isLoading) {
      return Center(
        child: isIos
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    final filtered = _filteredTasks();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildSegmentControl(isIos),
        const SizedBox(height: 12),
        _buildTaskFilters(context),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isIos ? CupertinoIcons.check_mark_circled : Icons.check_circle,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Нет заданий по выбранным фильтрам',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...filtered.map((task) => _TaskListItem(
                task: task,
                onTap: () => widget.onOpenTask(task),
                lateDaysBalance: widget.lateDaysBalance,
                onExtendDeadline: widget.onExtendDeadline != null ? () => widget.onExtendDeadline!(task) : null,
                onCancelLateDays: widget.onCancelLateDays != null ? () => widget.onCancelLateDays!(task) : null,
              )),
      ],
    );
  }

  Widget _buildSegmentControl(bool isIos) {
    final activeCount = _countForSegment(_activeStates);
    final archiveCount = _countForSegment(_archiveStates);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              icon: isIos ? CupertinoIcons.bolt_fill : Icons.flash_on,
              label: 'Активные',
              count: activeCount,
              index: 0,
              accentColor: const Color(0xFF00E676),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              icon: isIos ? CupertinoIcons.archivebox_fill : Icons.inventory_2,
              label: 'Архив',
              count: archiveCount,
              index: 1,
              accentColor: const Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required IconData icon,
    required String label,
    required int count,
    required int index,
    required Color accentColor,
  }) {
    final selected = _segment == index;
    final color = selected ? accentColor : Colors.grey[600]!;

    return GestureDetector(
      onTap: () => setState(() => _segment = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accentColor.withValues(alpha: 0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? accentColor.withValues(alpha: 0.2) : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? accentColor : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countForSegment(Set<String> states) {
    return widget.tasks.where((t) {
      if (_isCourseHidden(t.course)) return false;
      return states.contains(t.normalizedState);
    }).length;
  }

  Widget _buildTaskFilters(BuildContext context) {
    final counts = _taskCountsByState();
    final courseCounts = _taskCountsByCourse();
    final courseNames = _courseNamesById();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatusDropdown(
                counts: counts,
                statusFilters: widget.statusFilters,
                onStatusFiltersChanged: widget.onStatusFiltersChanged,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _resetFilters,
              icon: Icon(
                Platform.isIOS ? CupertinoIcons.refresh : Icons.refresh,
                color: Colors.grey[400],
                size: 18,
              ),
              label: Text(
                'Сбросить все',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _TaskSearchField(
          value: widget.searchQuery,
          onChanged: widget.onSearchQueryChanged,
        ),
        const SizedBox(height: 8),
        _CourseDropdown(
          counts: courseCounts,
          courseNames: courseNames,
          courseFilters: widget.courseFilters,
          onCourseFiltersChanged: widget.onCourseFiltersChanged,
        ),
      ],
    );
  }

  void _resetFilters() {
    widget.onStatusFiltersChanged({
      'backlog',
      'inProgress',
      'hasSolution',
      'revision',
      'review',
      'failed',
      'evaluated',
    });
    widget.onCourseFiltersChanged(<int>{});
    widget.onSearchQueryChanged('');
  }

  bool _isCourseHidden(TaskCourse course) {
    return course.isArchived || widget.userArchivedCourseIds.contains(course.id);
  }

  List<StudentTask> _filteredTasks() {
    final query = widget.searchQuery.trim().toLowerCase();
    final segmentStates = _statesForSegment;
    return widget.tasks
        .where((task) => !_isCourseHidden(task.course))
        .where((task) => segmentStates.contains(task.normalizedState))
        .where((task) => widget.statusFilters.contains(_normalizeForDisplay(task.normalizedState)))
        .where(
          (task) => widget.courseFilters.isEmpty || widget.courseFilters.contains(task.course.id),
        )
        .where(
          (task) =>
              query.isEmpty ||
              task.exercise.name.toLowerCase().contains(query),
        )
        .toList();
  }

  Map<String, int> _taskCountsByState() {
    final displayStates = _isActive ? _displayStatesActive : _displayStatesArchive;
    final segmentStates = _statesForSegment;
    final counts = <String, int>{};
    for (final state in displayStates) {
      counts[state] = 0;
    }
    for (final task in widget.tasks) {
      if (_isCourseHidden(task.course)) continue;
      final state = task.normalizedState;
      if (!segmentStates.contains(state)) continue;
      final key = _normalizeForDisplay(state);
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + 1;
      }
    }
    return counts;
  }

  Map<int, int> _taskCountsByCourse() {
    final segmentStates = _statesForSegment;
    final counts = <int, int>{};
    for (final task in widget.tasks) {
      if (_isCourseHidden(task.course)) continue;
      final state = task.normalizedState;
      if (!segmentStates.contains(state)) continue;
      if (!widget.statusFilters.contains(_normalizeForDisplay(state))) continue;
      counts[task.course.id] = (counts[task.course.id] ?? 0) + 1;
    }
    return counts;
  }

  Map<int, String> _courseNamesById() {
    final segmentStates = _statesForSegment;
    final names = <int, String>{};
    for (final task in widget.tasks) {
      if (_isCourseHidden(task.course)) continue;
      if (!segmentStates.contains(task.normalizedState)) continue;
      names[task.course.id] = task.course.cleanName;
    }
    return names;
  }
}

class _StatusDropdown extends StatelessWidget {
  final Map<String, int> counts;
  final Set<String> statusFilters;
  final void Function(Set<String>) onStatusFiltersChanged;

  const _StatusDropdown({
    required this.counts,
    required this.statusFilters,
    required this.onStatusFiltersChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return GestureDetector(
      onTap: () => _openStatusSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isIos ? CupertinoIcons.slider_horizontal_3 : Icons.filter_list,
              color: Colors.grey[500],
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedStatusLabel(),
                style: const TextStyle(fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isIos ? CupertinoIcons.chevron_down : Icons.keyboard_arrow_down,
              color: Colors.grey[500],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _selectedStatusLabel() {
    final relevant = statusFilters.where((s) => counts.containsKey(s));
    final labels = relevant.map((s) => _statusLabels[s] ?? s).toList();
    labels.sort();
    return labels.isEmpty ? 'Статусы' : 'Статусы: ${labels.join(', ')}';
  }

  Future<void> _openStatusSheet(BuildContext context) async {
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          return CupertinoPopupSurface(
            child: _StatusSheet(
              counts: counts,
              statusFilters: statusFilters,
              onStatusFiltersChanged: onStatusFiltersChanged,
            ),
          );
        },
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _StatusSheet(
          counts: counts,
          statusFilters: statusFilters,
          onStatusFiltersChanged: onStatusFiltersChanged,
        );
      },
    );
  }
}

class _TaskSearchField extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _TaskSearchField({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isIos ? CupertinoIcons.search : Icons.search,
            color: Colors.grey[500],
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isIos
                ? CupertinoTextField(
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: value,
                        selection: TextSelection.collapsed(offset: value.length),
                      ),
                    ),
                    placeholder: 'Поиск по заданиям...',
                    placeholderStyle: TextStyle(color: Colors.grey[500]),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(),
                    onChanged: onChanged,
                  )
                : TextField(
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: value,
                        selection: TextSelection.collapsed(offset: value.length),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск по заданиям...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: onChanged,
                  ),
          ),
          if (value.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => onChanged(''),
              icon: Icon(
                isIos ? CupertinoIcons.xmark_circle_fill : Icons.clear,
                color: Colors.grey[500],
                size: 16,
              ),
              tooltip: 'Очистить',
            ),
        ],
      ),
    );
  }
}

class _CourseDropdown extends StatelessWidget {
  final Map<int, int> counts;
  final Map<int, String> courseNames;
  final Set<int> courseFilters;
  final void Function(Set<int>) onCourseFiltersChanged;

  const _CourseDropdown({
    required this.counts,
    required this.courseNames,
    required this.courseFilters,
    required this.onCourseFiltersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openCourseSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.book : Icons.menu_book,
              color: Colors.grey[500],
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCourseLabel(),
                style: const TextStyle(fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Platform.isIOS ? CupertinoIcons.chevron_down : Icons.keyboard_arrow_down,
              color: Colors.grey[500],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _selectedCourseLabel() {
    if (courseFilters.isEmpty) return 'Курсы: все';
    final names = courseFilters
        .map((id) => courseNames[id])
        .whereType<String>()
        .toList()
      ..sort();
    if (names.length == 1) {
      return names.first;
    }
    return 'Курсы: ${names.length}';
  }

  Future<void> _openCourseSheet(BuildContext context) async {
    final isIos = Platform.isIOS;
    if (isIos) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          return CupertinoPopupSurface(
            child: _CourseSheet(
              counts: counts,
              courseNames: courseNames,
              courseFilters: courseFilters,
              onCourseFiltersChanged: onCourseFiltersChanged,
            ),
          );
        },
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _CourseSheet(
          counts: counts,
          courseNames: courseNames,
          courseFilters: courseFilters,
          onCourseFiltersChanged: onCourseFiltersChanged,
        );
      },
    );
  }
}

class _CourseSheet extends StatefulWidget {
  final Map<int, int> counts;
  final Map<int, String> courseNames;
  final Set<int> courseFilters;
  final void Function(Set<int>) onCourseFiltersChanged;

  const _CourseSheet({
    required this.counts,
    required this.courseNames,
    required this.courseFilters,
    required this.onCourseFiltersChanged,
  });

  @override
  State<_CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends State<_CourseSheet> {
  late Set<int> _localFilters;

  @override
  void initState() {
    super.initState();
    _localFilters = Set<int>.from(widget.courseFilters);
  }

  void _toggleFilter(int courseId) {
    setState(() {
      if (_localFilters.contains(courseId)) {
        _localFilters.remove(courseId);
      } else {
        _localFilters.add(courseId);
      }
    });
    widget.onCourseFiltersChanged(Set<int>.from(_localFilters));
  }

  void _clearFilters() {
    setState(() {
      _localFilters.clear();
    });
    widget.onCourseFiltersChanged(Set<int>.from(_localFilters));
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final courseIds = widget.courseNames.keys.toList()
      ..sort((a, b) => (widget.courseNames[a] ?? '').compareTo(widget.courseNames[b] ?? ''));
    final maxListHeight = MediaQuery.of(context).size.height * 0.5;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxListHeight + 120),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Фильтр по курсам',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (isIos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Все курсы',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                  CupertinoSwitch(
                    value: _localFilters.isEmpty,
                    activeTrackColor: const Color(0xFF00E676),
                    onChanged: (_) => _clearFilters(),
                  ),
                ],
              ),
            )
          else
            CheckboxListTile(
              value: _localFilters.isEmpty,
              dense: true,
              activeColor: const Color(0xFF00E676),
              checkColor: Colors.black,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Все курсы',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
              onChanged: (_) => _clearFilters(),
            ),
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: courseIds.length,
              itemBuilder: (context, index) {
                final courseId = courseIds[index];
                final name = widget.courseNames[courseId] ?? 'Курс';
                final count = widget.counts[courseId] ?? 0;
                final isSelected = _localFilters.contains(courseId);
                if (isIos) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$name ($count)',
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ),
                        CupertinoSwitch(
                          value: isSelected,
                          activeTrackColor: const Color(0xFF00E676),
                          onChanged: (_) => _toggleFilter(courseId),
                        ),
                      ],
                    ),
                  );
                }
                return CheckboxListTile(
                  value: isSelected,
                  dense: true,
                  activeColor: const Color(0xFF00E676),
                  checkColor: Colors.black,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '$name ($count)',
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  onChanged: (_) => _toggleFilter(courseId),
                );
              },
            ),
          ),
          if (isIos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Text('Готово'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSheet extends StatefulWidget {
  final Map<String, int> counts;
  final Set<String> statusFilters;
  final void Function(Set<String>) onStatusFiltersChanged;

  const _StatusSheet({
    required this.counts,
    required this.statusFilters,
    required this.onStatusFiltersChanged,
  });

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late Set<String> _localFilters;

  @override
  void initState() {
    super.initState();
    _localFilters = Set<String>.from(widget.statusFilters);
  }

  void _toggleFilter(String state) {
    setState(() {
      if (_localFilters.contains(state)) {
        _localFilters.remove(state);
      } else {
        _localFilters.add(state);
      }
      if (_localFilters.isEmpty) {
        _localFilters
          ..add('inProgress')
          ..add('review')
          ..add('backlog');
      }
    });
    widget.onStatusFiltersChanged(Set<String>.from(_localFilters));
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Фильтр по статусу',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        ...widget.counts.entries.map((e) => _buildStatusTile(
              _statusLabels[e.key] ?? e.key,
              e.key,
              e.value,
              isIos,
            )),
        if (isIos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile(String label, String state, int count, bool isIos) {
    final isSelected = _localFilters.contains(state);
    if (isIos) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label ($count)',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
            CupertinoSwitch(
              value: isSelected,
              activeTrackColor: const Color(0xFF00E676),
              onChanged: (value) => _toggleFilter(state),
            ),
          ],
        ),
      );
    }
    return CheckboxListTile(
      value: isSelected,
      dense: true,
      activeColor: const Color(0xFF00E676),
      checkColor: Colors.black,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        '$label ($count)',
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
      onChanged: (value) => _toggleFilter(state),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final StudentTask task;
  final VoidCallback onTap;
  final int lateDaysBalance;
  final VoidCallback? onExtendDeadline;
  final VoidCallback? onCancelLateDays;

  const _TaskListItem({
    required this.task,
    required this.onTap,
    this.lateDaysBalance = 0,
    this.onExtendDeadline,
    this.onCancelLateDays,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: task.stateBorderColor, width: 1),
      ),
      child: _buildContent(isIos),
    );
    if (isIos) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }

  Widget _buildContent(bool isIos) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.course.cleanName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.stateColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStateLabel(task),
                        style: TextStyle(
                          fontSize: 10,
                          color: task.stateColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (task.deadline != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        isIos ? CupertinoIcons.time : Icons.access_time,
                        size: 12,
                        color: task.isOverdue ? Colors.redAccent : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.formattedDeadline,
                        style: TextStyle(
                          fontSize: 11,
                          color: task.isOverdue ? Colors.redAccent : Colors.grey[500],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'макс. ${task.exercise.maxScore}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (task.canExtendDeadline) _buildLateDaysRow(isIos),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLateDaysRow(bool isIos) {
    final ld = task.lateDays ?? 0;
    final hasExtension = ld > 0;
    final canExtendMore = ld < 7 && lateDaysBalance > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (hasExtension) ...[
            Icon(
              isIos ? CupertinoIcons.clock_fill : Icons.schedule,
              size: 12,
              color: const Color(0xFFF6AD58),
            ),
            const SizedBox(width: 4),
            Text(
              'Перенесено на $ld дн.',
              style: const TextStyle(fontSize: 11, color: Color(0xFFF6AD58)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCancelLateDays,
              child: Text(
                'Отменить',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.grey[500],
                ),
              ),
            ),
            if (canExtendMore) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onExtendDeadline,
                child: const Text(
                  'Ещё перенести',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00E676),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF00E676),
                  ),
                ),
              ),
            ],
          ] else ...[
            GestureDetector(
              onTap: onExtendDeadline,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      isIos ? CupertinoIcons.calendar_badge_plus : Icons.event,
                      size: 12,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Перенести дедлайн',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF00E676),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStateLabel(StudentTask task) {
    switch (task.normalizedState) {
      case 'inProgress':
        return 'В работе';
      case 'review':
        return 'На проверке';
      case 'backlog':
        return 'Не начато';
      case 'hasSolution':
        return 'Есть решение';
      case 'revision':
      case 'rework':
        return 'Доработка';
      case 'failed':
      case 'rejected':
        return 'Не сдано';
      case 'evaluated':
        final score = task.formattedScore;
        if (score != null) {
          return '$score/${task.exercise.maxScore}';
        }
        return 'Проверено';
      default:
        return task.normalizedState;
    }
  }
}
