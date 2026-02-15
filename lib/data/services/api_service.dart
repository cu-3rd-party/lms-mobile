import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:cumobile/data/models/task_details.dart';
import 'package:cumobile/data/models/task_event.dart';
import 'package:cumobile/data/models/student_performance.dart';

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
    bool failed = false,
    bool evaluated = false,
  }) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final states = <String>[];
      if (inProgress) states.add('state=inProgress');
      if (review) states.add('state=review');
      if (backlog) states.add('state=backlog');
      if (failed) states.add('state=failed');
      if (evaluated) states.add('state=evaluated');

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

  Future<LongreadMaterial?> fetchMaterialById(int materialId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/materials/$materialId'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LongreadMaterial.fromJson(data);
      }
    } catch (e, st) {
      _log.warning('Error fetching material by id: $materialId', e, st);
    }
    return null;
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

  Future<UploadLinkData?> getUploadLink({
    required String directory,
    required String filename,
    required String contentType,
  }) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final encodedDirectory = Uri.encodeComponent(directory);
      final encodedFilename = Uri.encodeComponent(filename);
      final encodedContentType = Uri.encodeComponent(contentType);
      final response = await http.get(
        Uri.parse(
          '$baseUrl/micro-lms/content/upload-link?directory=$encodedDirectory&filename=$encodedFilename&contentType=$encodedContentType',
        ),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return UploadLinkData.fromJson(data);
        }
      }
    } catch (e, st) {
      _log.warning('Error getting upload link', e, st);
    }
    return null;
  }

  Future<bool> uploadFileToUrl({
    required String url,
    required File file,
    required String contentType,
    String? metaVersion,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final headers = <String, String>{
        'Content-Type': contentType,
      };
      if (metaVersion != null && metaVersion.isNotEmpty) {
        headers['x-amz-meta-version'] = metaVersion;
      }
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: bytes,
      );
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e, st) {
      _log.warning('Error uploading file', e, st);
      return false;
    }
  }

  Future<bool> uploadFileToUrlWithProgress({
    required String url,
    required File file,
    required String contentType,
    String? metaVersion,
    void Function(double progress)? onProgress,
  }) async {
    try {
      _log.info('Upload PUT: url=$url contentType=$contentType');
      final length = await file.length();
      final request = http.StreamedRequest('PUT', Uri.parse(url));
      request.headers['Content-Type'] = contentType;
      if (metaVersion != null && metaVersion.isNotEmpty) {
        request.headers['x-amz-meta-version'] = metaVersion;
      }
      request.contentLength = length;

      final responseFuture = request.send();
      var sent = 0;
      await for (final chunk in file.openRead()) {
        sent += chunk.length;
        request.sink.add(chunk);
        if (length > 0) {
          onProgress?.call(sent / length);
        }
      }
      await request.sink.close();

      final response = await responseFuture;
      await response.stream.drain();
      _log.info('Upload PUT response: status=${response.statusCode}');
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e, st) {
      _log.warning('Error uploading file', e, st);
      return false;
    }
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

  Future<TaskDetails?> fetchTaskDetails(int taskId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return TaskDetails.fromJson(data);
        }
      }
    } catch (e, st) {
      _log.warning('Error fetching task details', e, st);
    }
    return null;
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

  Future<bool> submitTaskSolution({
    required int taskId,
    String? solutionUrl,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/submit'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (solutionUrl != null && solutionUrl.isNotEmpty) 'solutionUrl': solutionUrl,
          'attachments': attachments,
        }),
      );

      await _handleResponse(response);
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e, st) {
      _log.warning('Error submitting task solution', e, st);
      return false;
    }
  }

  Future<bool> startTask(int taskId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/start'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
      );

      await _handleResponse(response);
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e, st) {
      _log.warning('Error starting task', e, st);
      return false;
    }
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

  Future<bool> prolongLateDays(int taskId, int lateDays) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/late-days-prolong'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'lateDays': lateDays}),
      );

      await _handleResponse(response);
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e, st) {
      _log.warning('Error prolonging late days', e, st);
      return false;
    }
  }

  Future<bool> cancelLateDays(int taskId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/late-days-cancel'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
      );

      await _handleResponse(response);
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e, st) {
      _log.warning('Error cancelling late days', e, st);
      return false;
    }
  }

  Future<StudentPerformanceResponse?> fetchStudentPerformance() async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/performance/student'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return StudentPerformanceResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching student performance', e, st);
    }
    return null;
  }

  Future<CourseExercisesResponse?> fetchCourseExercises(int courseId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/$courseId/exercises'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return CourseExercisesResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching course exercises', e, st);
    }
    return null;
  }

  Future<CourseStudentPerformanceResponse?> fetchCourseStudentPerformance(int courseId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/$courseId/student-performance'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return CourseStudentPerformanceResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching course student performance', e, st);
    }
    return null;
  }

  Future<GradebookResponse?> fetchGradebook() async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/gradebook'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return GradebookResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching gradebook', e, st);
    }
    return null;
  }
}

class UploadLinkData {
  final String shortName;
  final String filename;
  final String objectKey;
  final String version;
  final String url;

  UploadLinkData({
    required this.shortName,
    required this.filename,
    required this.objectKey,
    required this.version,
    required this.url,
  });

  factory UploadLinkData.fromJson(Map<String, dynamic> json) {
    return UploadLinkData(
      shortName: json['shortName'] ?? '',
      filename: json['filename'] ?? '',
      objectKey: json['objectKey'] ?? '',
      version: json['version'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

final ApiService apiService = ApiService();
