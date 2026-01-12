import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/longread_material.dart';
import 'package:cumobile/data/models/notification_item.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_profile.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/data/models/task_comment.dart';
import 'package:cumobile/data/models/task_event.dart';

class ApiService {
  static const String baseUrl = 'https://my.centraluniversity.ru/api';
  String? _cookie;
  static final Logger _log = Logger('ApiService');

  final _authRequiredController = StreamController<void>.broadcast();
  Stream<void> get onAuthRequired => _authRequiredController.stream;

  Future<void> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      _log.info('Received 401, auth required');
      await clearCookie();
      _authRequiredController.add(null);
      return;
    }

    final setCookieHeader = response.headers['set-cookie'];
    if (setCookieHeader != null && setCookieHeader.contains('bff.cookie=')) {
      final match = RegExp(r'bff\.cookie=([^;]+)').firstMatch(setCookieHeader);
      if (match != null) {
        final newCookie = Uri.decodeComponent(match.group(1)!);
        _log.info('Received new bff.cookie from Set-Cookie header');
        await setCookie(newCookie);
      }
    }
  }

  Future<void> setCookie(String cookie) async {
    _cookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookie', cookie);
  }

  Future<String?> getCookie() async {
    if (_cookie != null) return 'bff.cookie=$_cookie';
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('cookie');
    if (_cookie == null) return null;
    return 'bff.cookie=$_cookie';
  }

  Future<void> clearCookie() async {
    _cookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookie');
  }

  Future<StudentProfile?> fetchProfile() async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/hub/students/me'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return StudentProfile.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching profile', e, st);
    }
    return null;
  }

  Future<List<StudentTask>> fetchTasks({
    bool inProgress = true,
    bool review = false,
    bool backlog = true,
  }) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final states = <String>[];
      if (inProgress) states.add('state=inProgress');
      if (review) states.add('state=review');
      if (backlog) states.add('state=backlog');

      final queryString = states.join('&');
      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/tasks/student?$queryString'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => StudentTask.fromJson(e)).toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching tasks', e, st);
    }
    return [];
  }

  Future<List<Course>> fetchCourses() async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/student?limit=10000'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Course.fromJson(e)).toList();
        }
        if (data is Map<String, dynamic>) {
          final List<dynamic> items = data['items'] ?? [];
          return items.map((e) => Course.fromJson(e)).toList();
        }
      }
    } catch (e, st) {
      _log.warning('Error fetching courses', e, st);
    }
    return [];
  }

  Future<CourseOverview?> fetchCourseOverview(int courseId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/$courseId/overview'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return CourseOverview.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching course overview', e, st);
    }
    return null;
  }

  Future<List<LongreadMaterial>> fetchLongreadMaterials(int longreadId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/longreads/$longreadId/materials?limit=10000'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((e) => LongreadMaterial.fromJson(e)).toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching longread materials', e, st);
    }
    return [];
  }

  Future<String?> getDownloadLink(String filename, String version) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final encodedFilename = Uri.encodeComponent(filename);
      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/content/download-link?filename=$encodedFilename&version=$version'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
    } catch (e, st) {
      _log.warning('Error getting download link', e, st);
    }
    return null;
  }

  Future<StudentLmsProfile?> fetchStudentLmsProfile() async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/students/me'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return StudentLmsProfile.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching student LMS profile', e, st);
    }
    return null;
  }

  Future<List<TaskEvent>> fetchTaskEvents(int taskId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/events'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TaskEvent.fromJson(e)).toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching task events', e, st);
    }
    return [];
  }

  Future<List<TaskComment>> fetchTaskComments(int taskId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/comments'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TaskComment.fromJson(e)).toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching task comments', e, st);
    }
    return [];
  }

  Future<int?> createTaskComment({
    required int taskId,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/micro-lms/comments'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'entityId': taskId,
          'type': 'task',
          'content': content,
          'attachments': attachments,
        }),
      );

      await _handleResponse(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final commentId = data['commentId'];
          if (commentId is int) return commentId;
        }
      }
    } catch (e, st) {
      _log.warning('Error creating task comment', e, st);
    }
    return null;
  }

  Future<List<NotificationItem>> fetchNotifications({
    required int category,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.post(
        Uri.parse('$baseUrl/notification-hub/notifications/in-app'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paging': {
            'limit': limit,
            'offset': offset,
            'sorting': [],
          },
          'filter': {
            'category': category,
          },
        }),
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(NotificationItem.fromJson)
              .toList();
        }
        if (data is Map<String, dynamic>) {
          final List<dynamic> items = data['items'] ?? [];
          return items
              .whereType<Map<String, dynamic>>()
              .map(NotificationItem.fromJson)
              .toList();
        }
      }
    } catch (e, st) {
      _log.warning('Error fetching notifications', e, st);
    }
    return [];
  }
}

final ApiService apiService = ApiService();
