import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cumobile/core/services/demo_service.dart';
import 'package:cumobile/data/models/attendance.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_extras.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/longread_material.dart';
import 'package:cumobile/data/models/notification_item.dart';
import 'package:cumobile/data/models/quiz.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_profile.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/data/models/task_comment.dart';
import 'package:cumobile/data/models/task_details.dart';
import 'package:cumobile/data/models/task_event.dart';
import 'package:cumobile/data/models/student_performance.dart';

class ApiService {
  static const String baseUrl = 'https://my.centraluniversity.ru/api';
  static const int _coursesPagingCap = 2000;
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

  Future<Uint8List?> fetchAvatar() async {
    if (demoService.isDemoMode) return demoService.demoAvatar();
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/hub/avatars/me'),
        headers: {'Cookie': cookie},
      );
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<bool> uploadAvatar(Uint8List bytes, String filename, String mimeType) async {
    if (demoService.isDemoMode) return demoService.uploadAvatar(bytes);
    try {
      final cookie = await getCookie();
      if (cookie == null) return false;
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/hub/avatars/me'));
      request.headers['Cookie'] = cookie;
      request.files.add(http.MultipartFile.fromBytes(
        'File',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ));
      final response = await request.send();
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
    } catch (_) {}
    return false;
  }

  Future<bool> deleteAvatar() async {
    if (demoService.isDemoMode) return demoService.deleteAvatar();
    try {
      final cookie = await getCookie();
      if (cookie == null) return false;
      final response = await http.delete(
        Uri.parse('$baseUrl/hub/avatars/me'),
        headers: {'Cookie': cookie},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {}
    return false;
  }

  Future<StudentProfile?> fetchProfile() async {
    if (demoService.isDemoMode) return demoService.demoProfile();
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/student-hub/students/me'),
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

  Future<List<StudentTask>?> fetchTasks({
    bool inProgress = true,
    bool review = false,
    bool backlog = true,
    bool failed = false,
    bool evaluated = false,
  }) async {
    if (demoService.isDemoMode) {
      return demoService.demoTasks(
        inProgress: inProgress,
        review: review,
        backlog: backlog,
        failed: failed,
        evaluated: evaluated,
      );
    }
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final states = <String>[];
      if (inProgress) states.addAll(['state=inProgress', 'state=submitted', 'state=reworking']);
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
    return null;
  }

  Future<List<Course>> fetchCourses() async {
    if (demoService.isDemoMode) return demoService.demoCourses();
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/student?limit=10000'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return _parseCourses(response.body);
      }
    } catch (e, st) {
      _log.warning('Error fetching courses', e, st);
    }
    return [];
  }

  Future<List<Course>> fetchArchivedCourses({int pageSize = 20}) async {
    if (demoService.isDemoMode) {
      return demoService.demoCourses().where((c) => c.isArchived).toList();
    }
    return _fetchCoursesPaged(state: 'archived', pageSize: pageSize);
  }

  Future<List<Course>> _fetchCoursesPaged({
    required String state,
    int pageSize = 20,
  }) async {
    final result = <Course>[];
    final seenIds = <int>{};
    try {
      final cookie = await getCookie();
      if (cookie == null) return result;

      var offset = 0;
      while (offset < _coursesPagingCap) {
        final response = await http.get(
          Uri.parse(
            '$baseUrl/micro-lms/courses/student'
            '?offset=$offset&limit=$pageSize&state=$state',
          ),
          headers: {'Cookie': cookie},
        );

        await _handleResponse(response);
        if (response.statusCode != 200) break;

        final page = _parseCourses(response.body);
        final fresh = page.where((c) => seenIds.add(c.id)).toList();
        result.addAll(fresh);
        if (fresh.isEmpty || page.length < pageSize) break;
        offset += pageSize;
      }
    } catch (e, st) {
      _log.warning('Error fetching courses (state: $state)', e, st);
    }
    return result;
  }

  List<Course> _parseCourses(String body) {
    final data = jsonDecode(body);
    if (data is List) {
      return data.map((e) => Course.fromJson(e)).toList();
    }
    if (data is Map<String, dynamic>) {
      final List<dynamic> items = data['items'] ?? [];
      return items.map((e) => Course.fromJson(e)).toList();
    }
    return [];
  }

  Future<CourseOverview?> fetchCourseOverview(int courseId) async {
    if (demoService.isDemoMode) return demoService.demoCourseOverview(courseId);
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
    if (demoService.isDemoMode) return demoService.demoLongreadMaterials(longreadId);
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
    if (demoService.isDemoMode) return demoService.demoMaterialById(materialId);
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
    if (demoService.isDemoMode) return null;
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
    if (demoService.isDemoMode) {
      return UploadLinkData(
        shortName: filename,
        filename: '$directory/$filename',
        objectKey: '$directory/$filename',
        version: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        url: '',
      );
    }
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
    if (demoService.isDemoMode) {
      for (var step = 1; step <= 10; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        onProgress?.call(step / 10);
      }
      return true;
    }
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
    if (demoService.isDemoMode) return demoService.demoLmsProfile();
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
    if (demoService.isDemoMode) return demoService.demoTaskEvents(taskId);
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
    if (demoService.isDemoMode) return demoService.demoTaskComments(taskId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/tasks/$taskId/comments'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data is List ? data : (data is Map ? data['items'] as List? : null);
        final comments = <TaskComment>[];
        for (final item in items ?? const []) {
          if (item is! Map<String, dynamic>) continue;
          try {
            comments.add(TaskComment.fromJson(item));
          } catch (e, st) {
            _log.warning('Skipping malformed task comment', e, st);
          }
        }
        return comments;
      }
      _log.warning('Task comments request failed: ${response.statusCode}');
    } catch (e, st) {
      _log.warning('Error fetching task comments', e, st);
    }
    return [];
  }

  Future<TaskDetails?> fetchTaskDetails(int taskId) async {
    if (demoService.isDemoMode) return demoService.demoTaskDetails(taskId);
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

  static const _quizErrorCodes = [
    'attemptNotStarted',
    'attemptsLimitReached',
    'hasActiveAttempt',
    'invalidState',
  ];

  QuizActionResult _quizResult(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return const QuizActionResult(true);
    }
    final code = _quizErrorCodes.where(response.body.contains).firstOrNull;
    _log.warning('Quiz action failed: ${response.statusCode} ${code ?? ''}');
    return QuizActionResult(false, code);
  }

  Future<QuizTask?> fetchQuizTask(int taskId) async {
    if (demoService.isDemoMode) return demoService.demoQuizTask(taskId);
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
        if (data is Map<String, dynamic>) return QuizTask.fromJson(data);
      }
    } catch (e, st) {
      _log.warning('Error fetching quiz task', e, st);
    }
    return null;
  }

  Future<List<QuizPlayerQuestion>?> fetchQuizQuestions(int quizId) async {
    if (demoService.isDemoMode) return demoService.demoQuizQuestions(quizId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/quizzes/$quizId/questions'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(QuizPlayerQuestion.fromJson)
              .toList();
        }
      }
    } catch (e, st) {
      _log.warning('Error fetching quiz questions', e, st);
    }
    return null;
  }

  Future<QuizAttempt?> fetchQuizAttempt(int attemptId) async {
    if (demoService.isDemoMode) return demoService.demoQuizAttempt(attemptId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/quizzes/attempts/$attemptId'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return QuizAttempt.fromJson(data);
      }
    } catch (e, st) {
      _log.warning('Error fetching quiz attempt', e, st);
    }
    return null;
  }

  Future<QuizActionResult> startQuizAttempt(int sessionId) async {
    if (demoService.isDemoMode) return demoService.startQuizAttempt(sessionId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return const QuizActionResult(false);

      final response = await http.post(
        Uri.parse('$baseUrl/micro-lms/quizzes/attempts'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'sessionId': sessionId}),
      );

      await _handleResponse(response);
      return _quizResult(response);
    } catch (e, st) {
      _log.warning('Error starting quiz attempt', e, st);
    }
    return const QuizActionResult(false);
  }

  Future<QuizActionResult> submitQuizAnswer({
    required int attemptId,
    required int sessionId,
    required int questionId,
    required String type,
    required Object? answer,
  }) async {
    if (demoService.isDemoMode) {
      return demoService.submitQuizAnswer(attemptId, questionId, answer);
    }
    try {
      final cookie = await getCookie();
      if (cookie == null) return const QuizActionResult(false);

      final response = await http.post(
        Uri.parse('$baseUrl/micro-lms/quizzes/attempts/$attemptId/submit'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'answer': answer,
          'questionId': questionId,
          'sessionId': sessionId,
          'type': type,
        }),
      );

      await _handleResponse(response);
      return _quizResult(response);
    } catch (e, st) {
      _log.warning('Error submitting quiz answer', e, st);
    }
    return const QuizActionResult(false);
  }

  Future<QuizActionResult> completeQuizAttempt({
    required int attemptId,
    required int sessionId,
  }) async {
    if (demoService.isDemoMode) return demoService.completeQuizAttempt(attemptId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return const QuizActionResult(false);

      final response = await http.post(
        Uri.parse('$baseUrl/micro-lms/quizzes/attempts/$attemptId/complete'),
        headers: {
          'Cookie': cookie,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'sessionId': sessionId}),
      );

      await _handleResponse(response);
      return _quizResult(response);
    } catch (e, st) {
      _log.warning('Error completing quiz attempt', e, st);
    }
    return const QuizActionResult(false);
  }

  Future<String?> createTaskComment({
    required int taskId,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    if (demoService.isDemoMode) {
      return demoService.createTaskComment(taskId, content, attachments);
    }
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
          final commentId = data['commentId'] ?? data['id'];
          if (commentId != null) return commentId.toString();
        }
        return '';
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
    if (demoService.isDemoMode) {
      return demoService.submitTaskSolution(taskId, solutionUrl, attachments);
    }
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
    if (demoService.isDemoMode) return demoService.startTask(taskId);
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
    if (demoService.isDemoMode) return demoService.demoNotifications(category);
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
    if (demoService.isDemoMode) return demoService.prolongLateDays(taskId, lateDays);
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
    if (demoService.isDemoMode) return demoService.cancelLateDays(taskId);
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
    if (demoService.isDemoMode) return demoService.demoPerformance();
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

  Future<List<ActivityPerformance>?> fetchActivitiesPerformance(int courseId) async {
    if (demoService.isDemoMode) return demoService.demoActivitiesPerformance(courseId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/$courseId/activities-performance'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActivityPerformance.fromJson)
            .toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching activities performance', e, st);
    }
    return null;
  }

  Future<CourseExercisesResponse?> fetchCourseExercises(int courseId) async {
    if (demoService.isDemoMode) return demoService.demoCourseExercises(courseId);
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
    if (demoService.isDemoMode) return demoService.demoCourseStudentPerformance(courseId);
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
    if (demoService.isDemoMode) return demoService.demoGradebook();
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

  Future<CourseProgress?> fetchCourseProgress(int courseId) async {
    if (demoService.isDemoMode) return demoService.demoCourseProgress(courseId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/courses/$courseId/student/progress'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        return CourseProgress.fromJson(jsonDecode(response.body));
      }
    } catch (e, st) {
      _log.warning('Error fetching course progress', e, st);
    }
    return null;
  }

  Future<List<StudentTask>?> fetchDeadlines({int limit = 100, int? courseId}) async {
    if (demoService.isDemoMode) {
      return demoService.demoDeadlines(limit: limit, courseId: courseId);
    }
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final query = [
        'limit=$limit',
        if (courseId != null) 'courseId=$courseId',
      ].join('&');
      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/deadlines?$query'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map(StudentTask.fromJson)
            .toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching deadlines', e, st);
    }
    return null;
  }

  Future<List<RecordingHost>> fetchRecordingHosts(int courseId) async {
    if (demoService.isDemoMode) return demoService.demoRecordingHosts(courseId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/calendar-events/recording-hosts?courseId=$courseId'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map(RecordingHost.fromJson)
            .toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching recording hosts', e, st);
    }
    return [];
  }

  Future<RecordingEventsPage?> fetchRecordingEvents({
    required int courseId,
    int offset = 0,
    int limit = 100,
    bool myEvents = true,
    Iterable<String> eventTypes = const [],
    Iterable<String> hostEmails = const [],
  }) async {
    if (demoService.isDemoMode) {
      return demoService.demoRecordingEvents(
        courseId: courseId,
        offset: offset,
        limit: limit,
        eventTypes: eventTypes,
        hostEmails: hostEmails,
      );
    }
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final query = [
        'offset=$offset',
        'limit=$limit',
        'myEvents=$myEvents',
        ...eventTypes.map((t) => 'eventTypes=${Uri.encodeQueryComponent(t)}'),
        ...hostEmails.map((e) => 'hostEmails=${Uri.encodeQueryComponent(e)}'),
        'courseId=$courseId',
      ].join('&');
      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/calendar-events/recording-events?$query'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RecordingEvent.fromJson)
            .toList();
        final paging = data['paging'];
        final total = paging is Map ? (paging['totalCount'] as num?)?.toInt() : null;
        return RecordingEventsPage(items: items, totalCount: total ?? items.length);
      }
    } catch (e, st) {
      _log.warning('Error fetching recording events', e, st);
    }
    return null;
  }

  Future<List<EventRecording>?> fetchEventRecordings(String eventId, String actualDate) async {
    if (demoService.isDemoMode) return demoService.demoEventRecordings(eventId);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse(
          '$baseUrl/micro-lms/calendar-events/$eventId/recordings?actualDate=$actualDate',
        ),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map(EventRecording.fromJson)
            .where((r) => r.url.isNotEmpty)
            .toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching event recordings', e, st);
    }
    return null;
  }

  Future<List<AttendanceCourse>?> fetchAttendanceCourses({bool archived = false}) async {
    if (demoService.isDemoMode) return demoService.demoAttendanceCourses(archived: archived);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/v0/attendance/learn/courses?isArchived=$archived'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map(AttendanceCourse.fromJson)
            .toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching attendance courses', e, st);
    }
    return null;
  }

  Future<List<AttendanceEvent>?> fetchCourseEventsByDate(int courseId, String date) async {
    if (demoService.isDemoMode) return demoService.demoCourseEventsByDate(courseId, date);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/calendar-events/learn/courses/$courseId/events/$date'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map(AttendanceEvent.fromJson)
            .toList();
      }
    } catch (e, st) {
      _log.warning('Error fetching course events', e, st);
    }
    return null;
  }

  Future<Set<String>?> fetchAttendedEventIds(int courseId, String date) async {
    if (demoService.isDemoMode) return demoService.demoAttendedEventIds(courseId, date);
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/micro-lms/v0/attendance/learn/courses/$courseId/events/$date'),
        headers: {'Cookie': cookie},
      );

      await _handleResponse(response);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e.toString()).toSet();
      }
    } catch (e, st) {
      _log.warning('Error fetching attended events', e, st);
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
