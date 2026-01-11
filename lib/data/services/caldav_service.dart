import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

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

class CaldavService {
  static const String _baseUrl = 'https://caldav.yandex.ru/';
  static final Logger _log = Logger('CaldavService');

  Future<List<CalendarEvent>> fetchEventsForDay({
    required String email,
    required String password,
    required DateTime day,
  }) async {
    try {
      final home = await _fetchCalendarHome(email, password);
      if (home == null) return [];

      final calendars = await _fetchCalendars(email, password, home);
      if (calendars.isEmpty) return [];

      final startUtc = DateTime(day.year, day.month, day.day).toUtc();
      final endUtc = DateTime(day.year, day.month, day.day, 23, 59, 59).toUtc();

      final events = <CalendarEvent>[];
      for (final calendar in calendars) {
        final data = await _queryCalendar(
          email,
          password,
          calendar,
          startUtc,
          endUtc,
        );
        events.addAll(_parseCalendarData(data));
      }

      return events;
    } catch (e, st) {
      _log.warning('Error fetching CalDAV events', e, st);
      return [];
    }
  }

  Future<String?> _fetchCalendarHome(String email, String password) async {
    final principal = await _fetchPrincipalUrl(email, password);
    if (principal == null) return null;
    final response = await _sendRequest(
      Uri.parse(principal),
      method: 'PROPFIND',
      headers: _headers(email, password, depth: '0'),
      body: '''<?xml version="1.0" encoding="UTF-8"?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <C:calendar-home-set />
  </D:prop>
</D:propfind>''',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final document = XmlDocument.parse(response.body);
    final home = document
        .findAllElements('calendar-home-set', namespace: '*')
        .expand((node) => node.findAllElements('href', namespace: '*'))
        .map((node) => node.innerText.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (home.isEmpty) return null;
    return _resolveUrl(home);
  }

  Future<String?> _fetchPrincipalUrl(String email, String password) async {
    final response = await _sendRequest(
      Uri.parse(_baseUrl),
      method: 'PROPFIND',
      headers: _headers(email, password, depth: '0'),
      body: '''<?xml version="1.0" encoding="UTF-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:current-user-principal />
  </D:prop>
</D:propfind>''',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final document = XmlDocument.parse(response.body);
    final principal = document
        .findAllElements('current-user-principal', namespace: '*')
        .expand((node) => node.findAllElements('href', namespace: '*'))
        .map((node) => node.innerText.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (principal.isEmpty) return null;
    return _resolveUrl(principal);
  }

  Future<List<String>> _fetchCalendars(
    String email,
    String password,
    String homeUrl,
  ) async {
    final response = await _sendRequest(
      Uri.parse(homeUrl),
      method: 'PROPFIND',
      headers: _headers(email, password, depth: '1'),
      body: '''<?xml version="1.0" encoding="UTF-8"?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:displayname />
    <C:supported-calendar-component-set />
  </D:prop>
</D:propfind>''',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }

    final document = XmlDocument.parse(response.body);
    final responses = document.findAllElements('response', namespace: '*');
    final calendars = <String>[];
    for (final responseNode in responses) {
      final href = responseNode
          .findAllElements('href', namespace: '*')
          .map((node) => node.innerText.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (href.isEmpty) continue;

      final componentSet = responseNode
          .findAllElements('supported-calendar-component-set', namespace: '*')
          .expand((node) => node.findAllElements('comp', namespace: '*'))
          .map((node) => node.getAttribute('name'))
          .whereType<String>()
          .toList();
      if (!componentSet.contains('VEVENT')) continue;
      calendars.add(_resolveUrl(href));
    }
    return calendars;
  }

  Future<String> _queryCalendar(
    String email,
    String password,
    String calendarUrl,
    DateTime startUtc,
    DateTime endUtc,
  ) async {
    final response = await _sendRequest(
      Uri.parse(calendarUrl),
      method: 'REPORT',
      headers: _headers(email, password, depth: '1'),
      body: '''<?xml version="1.0" encoding="UTF-8"?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <C:calendar-data />
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VEVENT">
        <C:time-range start="${_formatUtc(startUtc)}" end="${_formatUtc(endUtc)}"/>
      </C:comp-filter>
    </C:comp-filter>
  </C:filter>
</C:calendar-query>''',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '';
    }
    return response.body;
  }

  Future<http.Response> _sendRequest(
    Uri uri, {
    required String method,
    required Map<String, String> headers,
    required String body,
  }) async {
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    request.body = body;
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  List<CalendarEvent> _parseCalendarData(String xmlBody) {
    if (xmlBody.isEmpty) return [];
    final document = XmlDocument.parse(xmlBody);
    final dataNodes =
        document.findAllElements('calendar-data', namespace: '*').toList();
    if (dataNodes.isEmpty) return [];

    final events = <CalendarEvent>[];
    for (final node in dataNodes) {
      final raw = node.innerText;
      if (raw.isEmpty) continue;
      final unfolded = raw.replaceAll(RegExp(r'\r?\n[ \\t]'), '');
      final blocks = unfolded.split('BEGIN:VEVENT');
      for (var i = 1; i < blocks.length; i++) {
        final block = blocks[i].split('END:VEVENT').first;
        final lines = block.split(RegExp(r'\r?\n'));
        String? summary;
        DateTime? start;
        DateTime? end;
        String? link;
        String? url;
        String? description;
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
          }
        }
        link = _extractKtalkUrl(url) ?? _extractKtalkUrl(description);
        if (summary == null || start == null) continue;
        end ??= start.add(const Duration(hours: 1));
        events.add(CalendarEvent(start: start, end: end, summary: summary, link: link));
      }
    }
    return events;
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

  String _formatUtc(DateTime time) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${pad(time.month)}${pad(time.day)}T${pad(time.hour)}${pad(time.minute)}${pad(time.second)}Z';
  }

  String _resolveUrl(String href) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) {
      return 'https://caldav.yandex.ru$href';
    }
    return 'https://caldav.yandex.ru/$href';
  }

  Map<String, String> _headers(
    String email,
    String password, {
    String? depth,
  }) {
    return {
      'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$password'))}',
      'Content-Type': 'application/xml; charset=utf-8',
      if (depth != null) 'Depth': depth,
    };
  }
}
