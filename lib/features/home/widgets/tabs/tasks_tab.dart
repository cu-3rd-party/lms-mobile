import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/data/models/student_task.dart';

class TasksTab extends StatelessWidget {
  final List<StudentTask> tasks;
  final bool isLoading;
  final Set<String> statusFilters;
  final void Function(Set<String>) onStatusFiltersChanged;
  final void Function(StudentTask) onOpenTask;

  const TasksTab({
    super.key,
    required this.tasks,
    required this.isLoading,
    required this.statusFilters,
    required this.onStatusFiltersChanged,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    if (isLoading) {
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
                onTap: () => onOpenTask(task),
              )),
      ],
    );
  }

  Widget _buildTaskFilters(BuildContext context) {
    final counts = _taskCountsByState();
    return Row(
      children: [
        Expanded(
          child: _StatusDropdown(
            counts: counts,
            statusFilters: statusFilters,
            onStatusFiltersChanged: onStatusFiltersChanged,
          ),
        ),
      ],
    );
  }

  List<StudentTask> _filteredTasks() {
    return tasks.where((task) => statusFilters.contains(task.state)).toList();
  }

  Map<String, int> _taskCountsByState() {
    final counts = <String, int>{
      'inProgress': 0,
      'review': 0,
      'backlog': 0,
    };
    for (final task in tasks) {
      if (counts.containsKey(task.state)) {
        counts[task.state] = counts[task.state]! + 1;
      }
    }
    return counts;
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
                style: TextStyle(fontSize: 12, color: Colors.grey[300]),
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
    final mapping = {
      'inProgress': 'В работе',
      'review': 'На проверке',
      'backlog': 'Не начато',
    };
    final labels = statusFilters.map((s) => mapping[s] ?? s).toList();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
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
          const SizedBox(height: 8),
          _buildStatusTile('В работе', 'inProgress', widget.counts['inProgress'] ?? 0, isIos),
          _buildStatusTile('На проверке', 'review', widget.counts['review'] ?? 0, isIos),
          _buildStatusTile('Не начато', 'backlog', widget.counts['backlog'] ?? 0, isIos),
          const SizedBox(height: 8),
          if (isIos)
            CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTile(String label, String state, int count, bool isIos) {
    final isSelected = _localFilters.contains(state);
    if (isIos) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  const _TaskListItem({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: task.isOverdue
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: (isIos
              ? GestureDetector(onTap: onTap, child: _buildContent(isIos))
              : InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildContent(isIos),
                )),
    );
  }

  Widget _buildContent(bool isIos) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: task.stateColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_taskTypeIcon(task.exercise.type, isIos),
                color: task.stateColor, size: 18),
          ),
          const SizedBox(width: 12),
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
                        _getStateLabel(task.state),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStateLabel(String state) {
    switch (state) {
      case 'inProgress':
        return 'В работе';
      case 'review':
        return 'На проверке';
      case 'backlog':
        return 'Не начато';
      default:
        return state;
    }
  }

  IconData _taskTypeIcon(String type, bool isIos) {
    switch (type) {
      case 'coding':
        return isIos
            ? CupertinoIcons.chevron_left_slash_chevron_right
            : Icons.code;
      case 'quiz':
        return isIos ? CupertinoIcons.question_circle : Icons.quiz;
      case 'essay':
        return isIos ? CupertinoIcons.doc_text : Icons.description;
      default:
        return isIos ? CupertinoIcons.square_list : Icons.assignment;
    }
  }
}
