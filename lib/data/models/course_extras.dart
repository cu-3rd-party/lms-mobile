class CourseProgress {
  final double earnedScore;
  final double leftToEarnScore;
  final double maxScore;

  const CourseProgress({
    required this.earnedScore,
    required this.leftToEarnScore,
    required this.maxScore,
  });

  factory CourseProgress.fromJson(Map<String, dynamic> json) {
    return CourseProgress(
      earnedScore: (json['earnedScore'] as num?)?.toDouble() ?? 0,
      leftToEarnScore: (json['leftToEarnScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
    );
  }

  static String format(double value) {
    final rounded = (value * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
    return rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  }
}

class RecordingHost {
  final String? id;
  final String? name;
  final String? email;

  const RecordingHost({this.id, this.name, this.email});

  factory RecordingHost.fromJson(Map<String, dynamic> json) {
    return RecordingHost(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
    );
  }

  static const String noHostId = '00000000-0000-0000-0000-000000000000';

  bool get isNoHost => id == noHostId;

  String get key => isNoHost ? noHostId : (email ?? id ?? name ?? '');

  String get displayName {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return email ?? 'Без имени';
  }
}

class RecordingEvent {
  final String id;
  final String title;
  final String type;
  final List<RecordingHost> hosts;
  final String actualDate;
  final String startTime;
  final String endTime;

  const RecordingEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.hosts,
    required this.actualDate,
    required this.startTime,
    required this.endTime,
  });

  factory RecordingEvent.fromJson(Map<String, dynamic> json) {
    final hosts = json['hosts'];
    final dt = json['eventDatetime'];
    final datetime = dt is Map ? dt : const {};
    return RecordingEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      hosts: hosts is List
          ? hosts.whereType<Map<String, dynamic>>().map(RecordingHost.fromJson).toList()
          : const [],
      actualDate: datetime['actualDate']?.toString() ?? '',
      startTime: datetime['startTime']?.toString() ?? '',
      endTime: datetime['endTime']?.toString() ?? '',
    );
  }

  DateTime? get date => DateTime.tryParse(actualDate);

  String get typeLabel => recordingEventTypes[type] ?? 'Другое';
}

class RecordingEventsPage {
  final List<RecordingEvent> items;
  final int totalCount;

  const RecordingEventsPage({required this.items, required this.totalCount});
}

const Map<String, String> recordingEventTypes = {
  'seminar': 'Семинар',
  'lecture': 'Лекция',
  'colloquium': 'Коллоквиум',
  'exam': 'Экзамен',
  'examRetakeWithCommittee': 'Пересдача с комиссией',
  'test': 'Контрольная',
  'examRetake': 'Пересдача',
  'officeHours': 'Office hours',
  'internalEvent': 'Внутреннее мероприятие',
  'individualConsultation': 'Индивидуальная консультация',
  'other': 'Другое',
};

class EventRecording {
  final String url;
  final int duration;

  const EventRecording({required this.url, required this.duration});

  factory EventRecording.fromJson(Map<String, dynamic> json) {
    return EventRecording(
      url: json['url']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
  }
}
