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
  final String? exerciseUrl;
  final bool isCodeEditorEnabled;
  final String? videoUrl;
  final String? videoState;
  final String? description;
  final int? attemptsLimit;
  final String? evaluationStrategy;

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
    this.exerciseUrl,
    this.isCodeEditorEnabled = false,
    this.videoUrl,
    this.videoState,
    this.description,
    this.attemptsLimit,
    this.evaluationStrategy,
  });

  factory LongreadMaterial.fromJson(Map<String, dynamic> json) {
    final content = parseRichContent(json['viewContent']);
    final settings = json['settings'];

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
      exerciseUrl: _nonEmpty(json['exerciseUrl'] ?? (json['coding'] is Map ? json['coding']['exerciseUrl'] : null)),
      isCodeEditorEnabled: json['isCodeEditorEnabled'] == true,
      videoUrl: json['discriminator'] == 'videoPlatform' ? _nonEmpty(json['url']) : null,
      videoState: json['videoState']?.toString(),
      description: _nonEmpty(json['description']),
      attemptsLimit: settings is Map ? (settings['attemptsLimit'] as num?)?.toInt() : null,
      evaluationStrategy: settings is Map ? settings['evaluationStrategy']?.toString() : null,
    );
  }

  bool get isMarkdown => discriminator == 'markdown';
  bool get isFile => discriminator == 'file';
  bool get isImage => discriminator == 'image';
  bool get isVideo => discriminator == 'videoPlatform';

  static const _viewableVideoStates = {'ready', 'partiallyReady', 'viewable'};

  bool get isViewableVideo =>
      isVideo && videoUrl != null && _viewableVideoStates.contains(videoState);
  bool get isCoding => discriminator == 'coding';
  bool get isQuestions => discriminator == 'questions';
  bool get isExercise => isCoding || isQuestions;

  bool get isCodeUnicorn => isCoding && isCodeEditorEnabled && exerciseUrl != null;

  DateTime? get opensAt {
    final start = estimation?.startDate;
    if (start == null || !start.isAfter(DateTime.now())) return null;
    return start;
  }

  String get formattedSize {
    if (length == null) return '';
    if (length! < 1024) return '$length B';
    if (length! < 1024 * 1024) return '${(length! / 1024).toStringAsFixed(1)} KB';
    return '${(length! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

String? _nonEmpty(dynamic raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String? parseRichContent(dynamic raw) {
  if (raw is Map) {
    return raw['value']?.toString() ?? raw['description']?.toString();
  }
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded['value']?.toString() ?? decoded['description']?.toString();
      }
    } catch (_) {}
    return raw;
  }
  return null;
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
  final DateTime? startDate;
  final DateTime? deadline;
  final int maxScore;
  final String? activityName;
  final double? activityWeight;

  MaterialEstimation({
    this.startDate,
    this.deadline,
    required this.maxScore,
    this.activityName,
    this.activityWeight,
  });

  factory MaterialEstimation.fromJson(Map<String, dynamic> json) {
    return MaterialEstimation(
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      maxScore: (json['maxScore'] as num?)?.toInt() ?? 0,
      activityName: json['activity']?['name'],
      activityWeight: (json['activity']?['weight'] as num?)?.toDouble(),
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
