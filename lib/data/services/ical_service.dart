import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class CalendarEvent {
  final DateTime start;
  final DateTime end;
  final String summary;
  final String? link;

  CalendarEvent({
    required this.start,
    required this.end,
    required this.summary,
    this.link,
  });
}

class IcalService {
  static final Logger _log = Logger('IcalService');
  static const String _cacheFileName = 'calendar_cache.ics';

  List<CalendarEvent>? _cachedEvents;
  String? _cachedContent;
  bool _isRefreshing = false;

  /// Загружает события для дня. Сначала из кеша, потом обновляет в фоне.
  Future<List<CalendarEvent>> fetchEventsForDay({
    required String icsUrl,
    required DateTime day,
    void Function(List<CalendarEvent>)? onUpdate,
  }) async {
    // Если есть кеш в памяти - сразу фильтруем
    if (_cachedEvents != null) {
      final events = _filterEventsForDay(_cachedEvents!, day);
      // Запускаем фоновое обновление
      _refreshInBackground(icsUrl, day, onUpdate);
      return events;
    }

    // Пробуем загрузить из локального файла
    final localEvents = await _loadFromLocalCache();
    if (localEvents != null) {
      _cachedEvents = localEvents;
      final events = _filterEventsForDay(localEvents, day);
      // Запускаем фоновое обновление
      _refreshInBackground(icsUrl, day, onUpdate);
      return events;
    }

    // Нет кеша - загружаем из сети
    final networkEvents = await _fetchFromNetwork(icsUrl);
    if (networkEvents != null) {
      _cachedEvents = networkEvents;
      return _filterEventsForDay(networkEvents, day);
    }

    return [];
  }

  /// Принудительное обновление из сети
  Future<List<CalendarEvent>?> forceRefresh(String icsUrl) async {
    final events = await _fetchFromNetwork(icsUrl);
    if (events != null) {
      _cachedEvents = events;
    }
    return events;
  }

  /// Очистка кеша
  Future<void> clearCache() async {
    _cachedEvents = null;
    _cachedContent = null;
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log.warning('Error clearing cache', e);
    }
  }

  void _refreshInBackground(
    String icsUrl,
    DateTime day,
    void Function(List<CalendarEvent>)? onUpdate,
  ) {
    if (_isRefreshing) return;
    _isRefreshing = true;

    _fetchFromNetwork(icsUrl).then((newEvents) {
      _isRefreshing = false;
      if (newEvents == null) return;

      _cachedEvents = newEvents;
      if (onUpdate != null) {
        final filtered = _filterEventsForDay(newEvents, day);
        onUpdate(filtered);
      }
    });
  }

  Future<List<CalendarEvent>?> _fetchFromNetwork(String icsUrl) async {
    try {
      final response = await http.get(Uri.parse(icsUrl));
      if (response.statusCode != 200) {
        _log.warning('Failed to fetch ICS: ${response.statusCode}');
        return null;
      }

      final content = response.body;

      // Проверяем, изменился ли контент
      if (content == _cachedContent) {
        return _cachedEvents;
      }

      // Сохраняем локально
      await _saveToLocalCache(content);
      _cachedContent = content;

      return _parseIcsContent(content);
    } catch (e, st) {
      _log.warning('Error fetching iCal events', e, st);
      return null;
    }
  }

  Future<List<CalendarEvent>?> _loadFromLocalCache() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      _cachedContent = content;
      return _parseIcsContent(content);
    } catch (e, st) {
      _log.warning('Error loading from cache', e, st);
      return null;
    }
  }

  Future<void> _saveToLocalCache(String content) async {
    try {
      final file = await _getCacheFile();
      await file.writeAsString(content);
    } catch (e, st) {
      _log.warning('Error saving to cache', e, st);
    }
  }

  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  List<CalendarEvent> _filterEventsForDay(List<CalendarEvent> events, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

    return events.where((event) {
      return event.start.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
             event.start.isBefore(dayEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<CalendarEvent> _parseIcsContent(String content) {
    final events = <CalendarEvent>[];
    final unfolded = content.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final blocks = unfolded.split('BEGIN:VEVENT');
    // Collect EXDATE values per event to skip cancelled occurrences
    final horizon = DateTime.now().add(const Duration(days: 400));

    for (var i = 1; i < blocks.length; i++) {
      final block = blocks[i].split('END:VEVENT').first;
      final lines = block.split(RegExp(r'\r?\n'));

      String? summary;
      DateTime? start;
      DateTime? end;
      String? link;
      String? url;
      String? description;
      String? rrule;
      final exdates = <DateTime>[];

      for (final line in lines) {
        final idx = line.indexOf(':');
        if (idx == -1) continue;
        final key = line.substring(0, idx);
        final value = line.substring(idx + 1);

        if (key.startsWith('SUMMARY')) {
          summary = _unescapeIcsText(value.trim());
        } else if (key.startsWith('URL')) {
          url = value.trim();
        } else if (key.startsWith('DESCRIPTION')) {
          description = _unescapeIcsText(value.trim());
        } else if (key.startsWith('DTSTART')) {
          start = _parseDateTime(value.trim());
        } else if (key.startsWith('DTEND')) {
          end = _parseDateTime(value.trim());
        } else if (key.startsWith('RRULE')) {
          rrule = value.trim();
        } else if (key.startsWith('EXDATE')) {
          for (final part in value.split(',')) {
            final dt = _parseDateTime(part.trim());
            if (dt != null) exdates.add(DateTime(dt.year, dt.month, dt.day));
          }
        }
      }

      link = _extractKtalkUrl(url) ?? _extractKtalkUrl(description);

      if (summary == null || start == null) continue;
      end ??= start.add(const Duration(hours: 1));
      final duration = end.difference(start);

      if (rrule != null) {
        final occurrences = _expandRrule(
          rrule: rrule,
          dtstart: start,
          duration: duration,
          horizon: horizon,
          exdates: exdates,
        );
        for (final occ in occurrences) {
          events.add(CalendarEvent(
            start: occ,
            end: occ.add(duration),
            summary: summary,
            link: link,
          ));
        }
      } else {
        events.add(CalendarEvent(
          start: start,
          end: end,
          summary: summary,
          link: link,
        ));
      }
    }

    return events;
  }

  List<DateTime> _expandRrule({
    required String rrule,
    required DateTime dtstart,
    required Duration duration,
    required DateTime horizon,
    List<DateTime> exdates = const [],
  }) {
    final params = <String, String>{};
    for (final part in rrule.split(';')) {
      final eq = part.indexOf('=');
      if (eq == -1) continue;
      params[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
    }

    final freq = params['FREQ']?.toUpperCase();
    if (freq == null) return [dtstart];

    final count = params['COUNT'] != null ? int.tryParse(params['COUNT']!) : null;
    final until = params['UNTIL'] != null ? _parseDateTime(params['UNTIL']!) : null;
    final interval = params['INTERVAL'] != null ? int.tryParse(params['INTERVAL']!) ?? 1 : 1;
    final byDay = params['BYDAY']?.split(',');

    final limit = until ?? horizon;
    final maxCount = count ?? 730; // safety cap

    final results = <DateTime>[];
    final exdateSet = exdates.toSet();

    bool isExcluded(DateTime dt) {
      return exdateSet.contains(DateTime(dt.year, dt.month, dt.day));
    }

    switch (freq) {
      case 'DAILY':
        var current = dtstart;
        while (current.isBefore(limit) && results.length < maxCount) {
          if (!isExcluded(current)) results.add(current);
          current = current.add(Duration(days: interval));
        }
        break;

      case 'WEEKLY':
        if (byDay != null && byDay.isNotEmpty) {
          final targetDays = byDay.map(_parseIcalDay).whereType<int>().toSet();
          if (targetDays.isEmpty) targetDays.add(dtstart.weekday);

          // Start from the week of dtstart
          var weekStart = dtstart.subtract(Duration(days: dtstart.weekday - 1));
          while (weekStart.isBefore(limit) && results.length < maxCount) {
            for (var wd = 1; wd <= 7 && results.length < maxCount; wd++) {
              if (!targetDays.contains(wd)) continue;
              final candidate = DateTime(
                weekStart.year,
                weekStart.month,
                weekStart.day + (wd - 1),
                dtstart.hour,
                dtstart.minute,
                dtstart.second,
              );
              if (candidate.isBefore(dtstart)) continue;
              if (candidate.isAfter(limit)) break;
              if (!isExcluded(candidate)) results.add(candidate);
            }
            weekStart = weekStart.add(Duration(days: 7 * interval));
          }
        } else {
          var current = dtstart;
          while (current.isBefore(limit) && results.length < maxCount) {
            if (!isExcluded(current)) results.add(current);
            current = current.add(Duration(days: 7 * interval));
          }
        }
        break;

      case 'MONTHLY':
        var current = dtstart;
        var i = 0;
        while (current.isBefore(limit) && results.length < maxCount && i < maxCount) {
          if (!isExcluded(current)) results.add(current);
          final nextMonth = current.month + interval;
          current = DateTime(
            current.year + (nextMonth - 1) ~/ 12,
            ((nextMonth - 1) % 12) + 1,
            dtstart.day,
            dtstart.hour,
            dtstart.minute,
            dtstart.second,
          );
          i++;
        }
        break;

      case 'YEARLY':
        var current = dtstart;
        while (current.isBefore(limit) && results.length < maxCount) {
          if (!isExcluded(current)) results.add(current);
          current = DateTime(
            current.year + interval,
            dtstart.month,
            dtstart.day,
            dtstart.hour,
            dtstart.minute,
            dtstart.second,
          );
        }
        break;

      default:
        results.add(dtstart);
    }

    return results;
  }

  int? _parseIcalDay(String day) {
    // Strip numeric prefix (e.g. "1MO" → "MO")
    final clean = day.replaceAll(RegExp(r'[^A-Z]'), '').toUpperCase();
    const mapping = {
      'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7,
    };
    return mapping[clean];
  }

  String? _extractKtalkUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'https?://centraluniversity\.ktalk\.ru/\S*').firstMatch(text);
    return match?.group(0);
  }

  String _unescapeIcsText(String text) {
    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\');
  }

  DateTime? _parseDateTime(String value) {
    if (value.length == 8) return null;
    if (value.endsWith('Z')) {
      final raw = value.replaceAll('Z', '');
      return _parseBasicDateTime(raw, isUtc: true)?.toLocal();
    }
    return _parseBasicDateTime(value, isUtc: false);
  }

  DateTime? _parseBasicDateTime(String value, {required bool isUtc}) {
    if (value.length < 15) return null;
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    final hour = int.tryParse(value.substring(9, 11));
    final minute = int.tryParse(value.substring(11, 13));
    final second = int.tryParse(value.substring(13, 15));
    if ([year, month, day, hour, minute, second].contains(null)) return null;
    if (isUtc) {
      return DateTime.utc(year!, month!, day!, hour!, minute!, second!);
    }
    return DateTime(year!, month!, day!, hour!, minute!, second!);
  }
}
