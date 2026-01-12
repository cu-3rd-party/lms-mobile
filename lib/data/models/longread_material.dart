import 'dart:convert';

class LongreadMaterial {
  final int id;
  final String discriminator;
  final String? viewContent;
  final String? filename;
  final String? version;
  final int? length;
  final String? contentName;
  final String? name;
  final List<MaterialAttachment> attachments;
  final MaterialEstimation? estimation;
  final int? taskId;

  LongreadMaterial({
    required this.id,
    required this.discriminator,
    this.viewContent,
    this.filename,
    this.version,
    this.length,
    this.contentName,
    this.name,
    this.attachments = const [],
    this.estimation,
    this.taskId,
  });

  factory LongreadMaterial.fromJson(Map<String, dynamic> json) {
    String? content;
    final viewContent = json['viewContent'];
    if (viewContent is Map) {
      content = viewContent['value']?.toString() ?? viewContent['description']?.toString();
    } else if (viewContent is String) {
      try {
        final decoded = jsonDecode(viewContent);
        if (decoded is Map) {
          content = decoded['value']?.toString() ?? decoded['description']?.toString();
        } else {
          content = viewContent;
        }
      } catch (_) {
        content = viewContent;
      }
    }

    return LongreadMaterial(
      id: json['id'] ?? 0,
      discriminator: json['discriminator'] ?? '',
      viewContent: content,
      filename: json['filename'],
      version: json['version'],
      length: json['length'],
      contentName: json['content']?['name'],
      name: json['name'],
      attachments: (json['attachments'] as List?)
              ?.map((e) => MaterialAttachment.fromJson(e))
              .toList() ??
          [],
      estimation: json['estimation'] != null
          ? MaterialEstimation.fromJson(json['estimation'])
          : null,
      taskId: json['taskId'],
    );
  }

  bool get isMarkdown => discriminator == 'markdown';
  bool get isFile => discriminator == 'file';
  bool get isCoding => discriminator == 'coding';
  bool get isQuestions => discriminator == 'questions';

  String get formattedSize {
    if (length == null) return '';
    if (length! < 1024) return '$length B';
    if (length! < 1024 * 1024) return '${(length! / 1024).toStringAsFixed(1)} KB';
    return '${(length! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MaterialAttachment {
  final String name;
  final String filename;
  final String mediaType;
  final int length;
  final String version;

  MaterialAttachment({
    required this.name,
    required this.filename,
    required this.mediaType,
    required this.length,
    required this.version,
  });

  factory MaterialAttachment.fromJson(Map<String, dynamic> json) {
    return MaterialAttachment(
      name: json['name'] ?? '',
      filename: json['filename'] ?? '',
      mediaType: json['mediaType'] ?? '',
      length: json['length'] ?? 0,
      version: json['version'] ?? '',
    );
  }

  String get formattedSize {
    if (length == 0) return '';
    if (length < 1024) return '$length B';
    if (length < 1024 * 1024) return '${(length / 1024).toStringAsFixed(1)} KB';
    return '${(length / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get extension {
    if (!name.contains('.')) return 'FILE';
    return name.split('.').last.toUpperCase();
  }
}

class MaterialEstimation {
  final DateTime? deadline;
  final int maxScore;
  final String? activityName;

  MaterialEstimation({
    this.deadline,
    required this.maxScore,
    this.activityName,
  });

  factory MaterialEstimation.fromJson(Map<String, dynamic> json) {
    return MaterialEstimation(
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      maxScore: json['maxScore'] ?? 0,
      activityName: json['activity']?['name'],
    );
  }

  bool get isOverdue => deadline != null && DateTime.now().isAfter(deadline!);

  String get formattedDeadline {
    if (deadline == null) return '';
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final d = deadline!.toLocal();
    return '${d.day} ${months[d.month - 1]}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
