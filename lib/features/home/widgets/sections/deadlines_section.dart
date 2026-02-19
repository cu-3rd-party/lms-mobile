import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/data/models/student_task.dart';

class DeadlinesSection extends StatelessWidget {
  final List<StudentTask> tasks;
  final bool isLoading;
  final bool hasError;
  final void Function(StudentTask task) onOpenTask;
  final Set<int> userArchivedCourseIds;

  const DeadlinesSection({
    super.key,
    required this.tasks,
    required this.isLoading,
    required this.onOpenTask,
    this.hasError = false,
    this.userArchivedCourseIds = const {},
  });

  bool _isCourseHidden(TaskCourse course) {
    return course.isArchived || userArchivedCourseIds.contains(course.id);
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final deadlineTasks = tasks
        .where((task) => !_isCourseHidden(task.course))
        .where(
          (task) =>
              task.normalizedState == 'backlog' ||
              task.normalizedState == 'inProgress' ||
              task.normalizedState == 'revision' ||
              task.normalizedState == 'rework',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Дедлайны',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (deadlineTasks.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${deadlineTasks.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: isIos
                  ? const CupertinoActivityIndicator(
                      radius: 14,
                      color: Color(0xFF00E676),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF00E676)),
            ),
          )
        else if (hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isIos ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Не удалось загрузить задания',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else if (deadlineTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
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
                    'Нет активных заданий',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: deadlineTasks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final task = deadlineTasks[index];
                return _TaskCard(
                  task: task,
                  onTap: () => onOpenTask(task),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StudentTask task;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: task.stateBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.exercise.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                task.course.cleanName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (task.deadline != null)
            Row(
              children: [
                Icon(
                  Platform.isIOS ? CupertinoIcons.time : Icons.access_time,
                  size: 12,
                  color: task.isOverdue ? Colors.redAccent : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.formattedDeadline,
                    style: TextStyle(
                      fontSize: 11,
                      color: task.isOverdue ? Colors.redAccent : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.stateColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getStateLabel(task),
                  style: TextStyle(
                    fontSize: 10,
                    color: task.stateColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (Platform.isIOS) {
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
