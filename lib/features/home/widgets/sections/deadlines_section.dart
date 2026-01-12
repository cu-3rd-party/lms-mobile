import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/data/models/student_task.dart';

class DeadlinesSection extends StatelessWidget {
  final List<StudentTask> tasks;
  final bool isLoading;

  const DeadlinesSection({
    super.key,
    required this.tasks,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final deadlineTasks = tasks.where((task) => task.state != 'review').toList();
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
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: deadlineTasks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final task = deadlineTasks[index];
                return _TaskCard(task: task);
              },
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StudentTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: task.isOverdue
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: task.stateColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _taskTypeIcon(task.exercise.type),
              color: task.stateColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  task.course.cleanName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.deadline != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Platform.isIOS ? CupertinoIcons.time : Icons.access_time,
                        size: 11,
                        color: task.isOverdue ? Colors.redAccent : Colors.grey[400],
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          task.formattedDeadline,
                          style: TextStyle(
                            fontSize: 10,
                            color: task.isOverdue ? Colors.redAccent : Colors.grey[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: task.stateColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStateLabel(task.state),
                          style: TextStyle(
                            fontSize: 9,
                            color: task.stateColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'макс. ${task.exercise.maxScore}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
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

  IconData _taskTypeIcon(String type) {
    final isIos = Platform.isIOS;
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
