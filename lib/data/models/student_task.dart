import 'package:flutter/material.dart';

class StudentTask {
  final int id;
  final String state;
  final int? score;
  final DateTime? deadline;
  final DateTime? submitAt;
  final TaskExercise exercise;
  final TaskCourse course;

  StudentTask({
    required this.id,
    required this.state,
    this.score,
    this.deadline,
    this.submitAt,
    required this.exercise,
    required this.course,
  });

  factory StudentTask.fromJson(Map<String, dynamic> json) {
    return StudentTask(
      id: json['id'] ?? 0,
      state: json['state'] ?? '',
      score: json['score'],
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      submitAt: json['submitAt'] != null ? DateTime.parse(json['submitAt']) : null,
      exercise: TaskExercise.fromJson(json['exercise'] ?? {}),
      course: TaskCourse.fromJson(json['course'] ?? {}),
    );
  }

  bool get isOverdue => deadline != null && DateTime.now().isAfter(deadline!);

  Duration? get timeLeft => deadline?.difference(DateTime.now());

  String get formattedDeadline {
    if (deadline == null) return '';
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final d = deadline!.toLocal();
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
    switch (state) {
      case 'inProgress':
        return const Color(0xFF00E676);
      case 'review':
        return const Color(0xFFFF9800);
      case 'backlog':
        return Colors.grey;
      default:
        return Colors.grey;
    }
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
