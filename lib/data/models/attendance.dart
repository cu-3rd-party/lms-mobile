class AttendanceStats {
  final double percent;
  final int attendedCount;
  final int enrolledCount;

  const AttendanceStats({
    required this.percent,
    required this.attendedCount,
    required this.enrolledCount,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      attendedCount: (json['attendedCount'] as num?)?.toInt() ?? 0,
      enrolledCount: (json['enrolledCount'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedPercent {
    final rounded = (percent * 100).round() / 100;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
    return '${text.replaceAll('.', ',')}%';
  }

  String get summary => '$attendedCount из $enrolledCount ($formattedPercent)';
}

class AttendanceCourse {
  final int courseId;
  final String courseName;
  final String studentStatus;
  final bool isVisibleForStudents;
  final AttendanceStats? stats;

  const AttendanceCourse({
    required this.courseId,
    required this.courseName,
    required this.studentStatus,
    required this.isVisibleForStudents,
    this.stats,
  });

  factory AttendanceCourse.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'];
    return AttendanceCourse(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseName: json['courseName']?.toString() ?? '',
      studentStatus: json['studentStatus']?.toString() ?? '',
      isVisibleForStudents: json['isVisibleForStudents'] == true,
      stats: stats is Map<String, dynamic> ? AttendanceStats.fromJson(stats) : null,
    );
  }

  String get cleanName =>
      courseName.replaceAll(RegExp(r'^[\u{1F300}-\u{1F9FF}]\s*', unicode: true), '');

  String get studentStatusLabel {
    switch (studentStatus) {
      case 'required':
        return 'Обязательный';
      case 'elective':
        return 'Факультатив';
      case 'listener':
        return 'Вольнослушатель';
      default:
        return studentStatus;
    }
  }
}

class AttendanceHost {
  final String email;
  final String name;

  const AttendanceHost({required this.email, required this.name});

  factory AttendanceHost.fromJson(Map<String, dynamic> json) {
    return AttendanceHost(
      email: json['email']?.toString() ?? '',
      name: (json['name']?.toString() ?? '').trim(),
    );
  }
}

class AttendanceEvent {
  final String eventId;
  final bool isParticipant;
  final String actualDate;
  final String startTime;
  final String endTime;
  final String title;
  final String eventType;
  final String format;
  final int? rowNumber;
  final String? locationTitle;
  final List<AttendanceHost> hosts;

  const AttendanceEvent({
    required this.eventId,
    required this.isParticipant,
    required this.actualDate,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.eventType,
    required this.format,
    this.rowNumber,
    this.locationTitle,
    this.hosts = const [],
  });

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    final hosts = json['hosts'];
    return AttendanceEvent(
      eventId: json['eventId']?.toString() ?? '',
      isParticipant: json['isParticipant'] == true,
      actualDate: json['actualDate']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      rowNumber: (json['rowNumber'] as num?)?.toInt(),
      locationTitle: json['locationTitle']?.toString(),
      hosts: hosts is List
          ? hosts.whereType<Map<String, dynamic>>().map(AttendanceHost.fromJson).toList()
          : const [],
    );
  }

  String get typeLabel {
    final base = switch (eventType) {
      'seminar' => 'Семинар',
      'lecture' => 'Лекция',
      'practice' => 'Практика',
      'lab' => 'Лабораторная',
      'exam' => 'Экзамен',
      'consultation' => 'Консультация',
      _ => 'Занятие',
    };
    return rowNumber == null ? base : '$base $rowNumber';
  }

  String get formatLabel {
    switch (format) {
      case 'offline':
        return 'Очно';
      case 'online':
        return 'Онлайн';
      default:
        return '';
    }
  }

  String get hostNames => hosts.map((h) => h.name).where((n) => n.isNotEmpty).join(', ');

  DateTime? get endDateTime {
    final date = DateTime.tryParse(actualDate);
    if (date == null) return null;
    final parts = endTime.split(':');
    if (parts.length < 2) return date;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }
}
