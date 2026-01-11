import 'package:cumobile/data/models/longread_material.dart';

class TaskEvent {
  final String id;
  final DateTime? occurredOn;
  final String type;
  final String? actorEmail;
  final String? actorName;
  final TaskEventContent content;

  TaskEvent({
    required this.id,
    required this.occurredOn,
    required this.type,
    this.actorEmail,
    this.actorName,
    required this.content,
  });

  factory TaskEvent.fromJson(Map<String, dynamic> json) {
    return TaskEvent(
      id: json['id']?.toString() ?? '',
      occurredOn: json['occurredOn'] != null ? DateTime.tryParse(json['occurredOn']) : null,
      type: json['type'] ?? '',
      actorEmail: json['actorEmail'],
      actorName: json['actorName'],
      content: TaskEventContent.fromJson(json['content'] ?? const {}),
    );
  }
}

class TaskEventContent {
  final String? state;
  final TaskEventScore? score;
  final TaskEventEstimation? estimation;
  final List<MaterialAttachment> attachments;
  final String? solutionUrl;
  final String? reviewerName;
  final List<String>? reviewersNames;
  final String? taskState;
  final DateTime? taskDeadline;
  final String? exerciseName;

  TaskEventContent({
    this.state,
    this.score,
    this.estimation,
    this.attachments = const [],
    this.solutionUrl,
    this.reviewerName,
    this.reviewersNames = const [],
    this.taskState,
    this.taskDeadline,
    this.exerciseName,
  });

  factory TaskEventContent.fromJson(Map<String, dynamic> json) {
    final attachments = <MaterialAttachment>[];

    final solutionAttachments = json['solution']?['attachments'];
    if (solutionAttachments is List) {
      attachments.addAll(solutionAttachments
          .whereType<Map<String, dynamic>>()
          .map(MaterialAttachment.fromJson));
    }
    final solutionUrl = json['solution']?['solutionUrl']?.toString();

    final attached = json['attached'];
    if (attached is List) {
      attachments.addAll(
        attached.whereType<Map<String, dynamic>>().map(MaterialAttachment.fromJson),
      );
    }

    String? reviewerName;
    final reviewer = json['reviewer'];
    if (reviewer is Map) {
      final name = reviewer['name'];
      if (name is Map) {
        reviewerName = _fullName(
          name['last']?.toString(),
          name['first']?.toString(),
          name['middle']?.toString(),
        );
      }
    }

    final reviewersNames = <String>[];
    final reviewers = json['reviewers'];
    if (reviewers is List) {
      for (final item in reviewers) {
        if (item is Map) {
          final name = item['name'];
          if (name is Map) {
            final full = _fullName(
              name['last']?.toString(),
              name['first']?.toString(),
              name['middle']?.toString(),
            );
            if (full.isNotEmpty) reviewersNames.add(full);
          }
        }
      }
    }

    TaskEventEstimation? estimation;
    if (json['estimation'] != null) {
      estimation = TaskEventEstimation.fromJson(json['estimation']);
    }

    String? taskState;
    DateTime? taskDeadline;
    final task = json['task'];
    if (task is Map) {
      taskState = task['state']?.toString();
      if (task['deadline'] != null) {
        taskDeadline = DateTime.tryParse(task['deadline'].toString());
      }
      if (estimation == null && task['estimation'] != null) {
        estimation = TaskEventEstimation.fromJson(task['estimation']);
      }
    }

    return TaskEventContent(
      state: json['state'],
      score: json['score'] != null ? TaskEventScore.fromJson(json['score']) : null,
      estimation: estimation,
      attachments: attachments,
      solutionUrl: solutionUrl,
      reviewerName: reviewerName,
      reviewersNames: reviewersNames,
      taskState: taskState,
      taskDeadline: taskDeadline,
      exerciseName: json['name']?.toString(),
    );
  }
}

String _fullName(String? last, String? first, String? middle) {
  final parts =
      [last, first, middle].whereType<String>().where((part) => part.isNotEmpty).toList();
  return parts.join(' ');
}

class TaskEventScore {
  final String? level;
  final int? value;

  TaskEventScore({this.level, this.value});

  factory TaskEventScore.fromJson(Map<String, dynamic> json) {
    return TaskEventScore(
      level: json['level']?.toString(),
      value: json['value'] is int ? json['value'] as int : null,
    );
  }
}

class TaskEventEstimation {
  final DateTime? deadline;
  final int? maxScore;
  final String? activityName;

  TaskEventEstimation({this.deadline, this.maxScore, this.activityName});

  factory TaskEventEstimation.fromJson(Map<String, dynamic> json) {
    return TaskEventEstimation(
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      maxScore: json['maxScore'] is int ? json['maxScore'] as int : null,
      activityName: json['activity']?['name'],
    );
  }
}
