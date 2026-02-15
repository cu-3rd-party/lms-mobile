import 'package:cumobile/data/models/longread_material.dart';

class TaskDetails {
  final int id;
  final double? score;
  final double? extraScore;
  final int? maxScore;
  final int? scoreSkillLevel;
  final String? state;
  final String? solutionUrl;
  final List<MaterialAttachment> solutionAttachments;
  final DateTime? submitAt;
  final bool hasSolution;
  final bool isLateDaysEnabled;
  final int? lateDays;
  final int? lateDaysBalance;

  TaskDetails({
    required this.id,
    this.score,
    this.extraScore,
    this.maxScore,
    this.scoreSkillLevel,
    this.state,
    this.solutionUrl,
    List<MaterialAttachment>? solutionAttachments,
    this.submitAt,
    this.hasSolution = false,
    this.isLateDaysEnabled = false,
    this.lateDays,
    this.lateDaysBalance,
  }) : solutionAttachments = solutionAttachments ?? const [];

  TaskDetails copyWith({
    String? state,
    int? lateDays,
    int? lateDaysBalance,
    bool clearLateDays = false,
  }) {
    return TaskDetails(
      id: id,
      score: score,
      extraScore: extraScore,
      maxScore: maxScore,
      scoreSkillLevel: scoreSkillLevel,
      state: state ?? this.state,
      solutionUrl: solutionUrl,
      solutionAttachments: solutionAttachments,
      submitAt: submitAt,
      hasSolution: hasSolution,
      isLateDaysEnabled: isLateDaysEnabled,
      lateDays: clearLateDays ? null : (lateDays ?? this.lateDays),
      lateDaysBalance: lateDaysBalance ?? this.lateDaysBalance,
    );
  }

  factory TaskDetails.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score'];
    final rawExtraScore = json['extraScore'];
    final rawLevel = json['scoreSkillLevel'];
    final exercise = json['exercise'];
    final scoreSkillLevel = _parseSkillLevel(rawLevel);
    final solution = json['solution'];
    final solutionUrl =
        solution is Map<String, dynamic> ? solution['solutionUrl']?.toString() : null;
    final solutionAttachments = <MaterialAttachment>[];
    if (solution is Map<String, dynamic>) {
      final attachments = solution['attachments'];
      if (attachments is List) {
        solutionAttachments.addAll(
          attachments.whereType<Map<String, dynamic>>().map(MaterialAttachment.fromJson),
        );
      }
    }
    final submitAt =
        json['submitAt'] != null ? DateTime.tryParse(json['submitAt'].toString()) : null;
    final student = json['student'];
    final lateDaysBalance =
        student is Map<String, dynamic> ? student['lateDaysBalance'] as int? : null;
    return TaskDetails(
      id: json['id'] ?? 0,
      score: rawScore is num ? rawScore.toDouble() : null,
      extraScore: rawExtraScore is num ? rawExtraScore.toDouble() : null,
      maxScore: exercise is Map ? exercise['maxScore'] as int? : null,
      scoreSkillLevel: scoreSkillLevel,
      state: json['state']?.toString(),
      solutionUrl: solutionUrl,
      solutionAttachments: solutionAttachments,
      submitAt: submitAt,
      hasSolution: submitAt != null,
      isLateDaysEnabled: json['isLateDaysEnabled'] ?? false,
      lateDays: json['lateDays'] as int?,
      lateDaysBalance: lateDaysBalance,
    );
  }
}

int? _parseSkillLevel(dynamic rawLevel) {
  if (rawLevel == null) return null;
  if (rawLevel is num) {
    final value = rawLevel.toInt();
    return value > 0 ? value : null;
  }
  if (rawLevel is String) {
    switch (rawLevel.toLowerCase()) {
      case 'basic':
      case 'base':
      case 'level1':
      case 'lvl1':
      case 'beginner':
        return 1;
      case 'medium':
      case 'middle':
      case 'intermediate':
      case 'level2':
      case 'lvl2':
        return 2;
      case 'advanced':
      case 'pro':
      case 'level3':
      case 'lvl3':
        return 3;
    }
    final parsed = int.tryParse(rawLevel);
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}
