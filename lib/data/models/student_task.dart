import 'package:flutter/material.dart';

class StudentTask {
  static const Color backlogColor = Color(0xFF9E9E9E);
  static const Color inProgressColor = Color(0xFF6087DC);
  static const Color reviewColor = Color(0xFFF6AD58);
  static const Color hasSolutionColor = Color(0xFF28A745);
  static const Color revisionColor = Color(0xFFFE456A);
  static const Color failedColor = Color(0xFFEF5350);
  static const Color evaluatedColor = Color(0xFF00E676);

  static const Map<String, Color> statusColors = {
    'backlog': backlogColor,
    'inProgress': inProgressColor,
    'review': reviewColor,
    'hasSolution': hasSolutionColor,
    'revision': revisionColor,
    'rework': revisionColor,
    'failed': failedColor,
    'rejected': failedColor,
    'evaluated': evaluatedColor,
  };

  final int id;
  final String state;
  final double? score;
  final DateTime? deadline;
  final DateTime? submitAt;
  final TaskExercise exercise;
  final TaskCourse course;
  final bool isLateDaysEnabled;
  final int? lateDays;

  StudentTask({
    required this.id,
    required this.state,
    this.score,
    this.deadline,
    this.submitAt,
    required this.exercise,
    required this.course,
    this.isLateDaysEnabled = false,
    this.lateDays,
  });

  factory StudentTask.fromJson(Map<String, dynamic> json) {
    return StudentTask(
      id: json['id'] ?? 0,
      state: json['state'] ?? '',
      score: (json['score'] as num?)?.toDouble(),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      submitAt: json['submitAt'] != null ? DateTime.parse(json['submitAt']) : null,
      exercise: TaskExercise.fromJson(json['exercise'] ?? {}),
      course: TaskCourse.fromJson(json['course'] ?? {}),
      isLateDaysEnabled: json['isLateDaysEnabled'] ?? false,
      lateDays: json['lateDays'] as int?,
    );
  }

  /// Бэкенд уже включает lateDays в поле deadline,
  /// поэтому effectiveDeadline == deadline.
  DateTime? get effectiveDeadline => deadline;

  bool get canExtendDeadline {
    if (!isLateDaysEnabled) return false;
    const blocked = {'review', 'evaluated', 'revision', 'rework'};
    return !blocked.contains(normalizedState);
  }

  bool get canCancelLateDays {
    if ((lateDays ?? 0) == 0) return false;
    final d = effectiveDeadline;
    if (d == null) return true;
    return d.difference(DateTime.now()) > const Duration(hours: 24);
  }

  bool get isOverdue {
    final d = effectiveDeadline;
    return d != null && DateTime.now().isAfter(d);
  }

  Duration? get timeLeft => effectiveDeadline?.difference(DateTime.now());

  String get normalizedState {
    switch (state) {
      case 'evaluated':
      case 'review':
      case 'failed':
      case 'rejected':
      case 'revision':
      case 'rework':
      case 'backlog':
        return state;
      case 'inProgress':
        return submitAt != null ? 'hasSolution' : 'inProgress';
      case 'hasSolution':
        return submitAt != null ? 'hasSolution' : 'inProgress';
      default:
        return submitAt != null ? 'hasSolution' : state;
    }
  }

  String get formattedDeadline {
    final dl = effectiveDeadline;
    if (dl == null) return '';
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final d = dl.toLocal();
    return '${d.day} ${months[d.month - 1]}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  IconData get typeIcon {
    switch (exercise.type) {
      case 'coding':
        return Icons.code;
      case 'quiz':
        return Icons.quiz;
      case 'essay':
        return Icons.description;
      default:
        return Icons.assignment;
    }
  }

  Color get stateColor {
    return statusColors[normalizedState] ?? backlogColor;
  }

  Color get stateBorderColor => stateColor.withValues(alpha: 0.5);

  String? get formattedScore {
    final value = score;
    if (value == null) return null;
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}

class TaskExercise {
  final int id;
  final String name;
  final String type;
  final int maxScore;
  final DateTime? deadline;

  TaskExercise({
    required this.id,
    required this.name,
    required this.type,
    required this.maxScore,
    this.deadline,
  });

  factory TaskExercise.fromJson(Map<String, dynamic> json) {
    return TaskExercise(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      maxScore: json['maxScore'] ?? 0,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    );
  }
}

class TaskCourse {
  final int id;
  final String name;
  final bool isArchived;

  TaskCourse({
    required this.id,
    required this.name,
    required this.isArchived,
  });

  factory TaskCourse.fromJson(Map<String, dynamic> json) {
    return TaskCourse(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isArchived: json['isArchived'] ?? false,
    );
  }

  String get cleanName => name.replaceAll(RegExp(r'^[\u{1F300}-\u{1F9FF}]\s*', unicode: true), '');
}
