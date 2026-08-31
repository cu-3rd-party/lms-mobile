import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:cumobile/data/models/exam_item.dart';

class ExamsService {
  static final Logger _log = Logger('ExamsService');
  static const String backendUrl = 'https://lms.exams.cu3rd.ru';
  static const Duration _cacheTtl = Duration(minutes: 30);
  static const String _defaultSemesterStart = '01 09';

  Map<String, List<ExamItem>>? _scheduleCache;
  DateTime? _scheduleCachedAt;
  DateTime? _semesterStartCache;
  DateTime? _configCachedAt;

  Future<List<ExamItem>> fetchForCourse(String courseTitle) async {
    final results = await Future.wait([
      _fetchSchedule(),
      _fetchSemesterStart(),
    ]);
    final schedule = results[0] as Map<String, List<ExamItem>>;
    final semesterStart = results[1] as DateTime?;

    if (schedule.isEmpty) return [];

    final title = _normalize(courseTitle);
    if (title.isEmpty) return [];

    List<ExamItem>? matched;
    for (final entry in schedule.entries) {
      final key = _normalize(entry.key);
      if (key.isNotEmpty && title.contains(key)) {
        matched = entry.value;
        break;
      }
    }
    if (matched == null) return [];

    final now = DateTime.now();
    final threshold = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final upcoming = matched
        .where((item) => item.date != null && !item.date!.isBefore(threshold))
        .map((item) => item.withWeek(_weekNumber(item.date!, semesterStart)))
        .toList();

    upcoming.sort((a, b) => a.date!.compareTo(b.date!));
    return upcoming;
  }

  static int? _weekNumber(DateTime date, DateTime? semesterStart) {
    if (semesterStart == null) return null;
    final days = date.difference(semesterStart).inDays;
    final week = (days / 7).floor() + 1;
    return week >= 1 ? week : null;
  }

  Future<Map<String, List<ExamItem>>> _fetchSchedule() async {
    final cache = _scheduleCache;
    if (cache != null && _isFresh(_scheduleCachedAt)) return cache;

    final decoded = await _fetchJson('$backendUrl/api/schedule');
    if (decoded is! Map<String, dynamic>) return cache ?? {};

    final parsed = <String, List<ExamItem>>{};
    decoded.forEach((courseName, value) {
      if (value is! List) return;
      final items = value
          .whereType<Map<String, dynamic>>()
          .map(ExamItem.fromJson)
          .where((e) => e.name.isNotEmpty)
          .toList();
      if (items.isNotEmpty) parsed[courseName] = items;
    });

    _scheduleCache = parsed;
    _scheduleCachedAt = DateTime.now();
    return parsed;
  }

  Future<DateTime?> _fetchSemesterStart() async {
    if (_semesterStartCache != null && _isFresh(_configCachedAt)) {
      return _semesterStartCache;
    }

    final decoded = await _fetchJson('$backendUrl/api/config');
    final raw = decoded is Map<String, dynamic>
        ? (decoded['semesterStart'] ?? _defaultSemesterStart).toString()
        : _defaultSemesterStart;

    final parsed = ExamItem.parseDate(raw) ?? ExamItem.parseDate(_defaultSemesterStart);
    if (parsed != null) {
      _semesterStartCache = parsed;
      _configCachedAt = DateTime.now();
    }
    return parsed ?? _semesterStartCache;
  }

  Future<dynamic> _fetchJson(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _log.warning('$url returned ${response.statusCode}');
        return null;
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e, st) {
      _log.warning('Error fetching $url', e, st);
      return null;
    }
  }

  static bool _isFresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _cacheTtl;

  static String _normalize(String value) {
    return value
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }
}

final examsService = ExamsService();
