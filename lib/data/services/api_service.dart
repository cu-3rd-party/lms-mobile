import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cumobile/core/services/demo_service.dart';
import 'package:cumobile/data/services/api_cache.dart';
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
    await ApiCache.instance.clear();
  }

  Future<T?> _cachedRequest<T>({
    required String cacheKey,
    required Duration maxAge,
    required Future<http.Response> Function(String cookie) send,
    required T? Function(dynamic json) parse,
    required String label,
    void Function(T value)? onCached,
  }) async {
    T? cachedValue;
    var isCacheRead = false;
    Future<T?> readCache() async {
      if (isCacheRead) return cachedValue;
      isCacheRead = true;
      final body = await ApiCache.instance.read(cacheKey, maxAge);
      if (body == null) return null;
      try {
        cachedValue = parse(jsonDecode(body));
      } catch (e, st) {
        _log.fine('Ignoring unreadable cache for $cacheKey', e, st);
      }
      return cachedValue;
    }

    if (onCached != null) {
      final value = await readCache();
      if (value != null) onCached(value);
    }
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;
      final response = await send(cookie);
      await _handleResponse(response);
      if (response.statusCode == 401) return null;
      if (response.statusCode == 200) {
        final value = parse(jsonDecode(response.body));
        if (value != null) unawaited(ApiCache.instance.write(cacheKey, response.body));
        return value;
      }
      _log.warning('$label failed: ${response.statusCode}');
    } catch (e, st) {
      _log.warning('Error $label', e, st);
    }
    return readCache();
  }

  Future<T?> _cachedGet<T>(
    String path, {
    required Duration maxAge,
    required T? Function(dynamic json) parse,
    required String label,
    void Function(T value)? onCached,
  }) {
    return _cachedRequest(
      cacheKey: path,
      maxAge: maxAge,
      send: (cookie) => http.get(Uri.parse('$baseUrl$path'), headers: {'Cookie': cookie}),
      parse: parse,
      label: label,
      onCached: onCached,
    );
  }

  static List<T> _parseList<T>(dynamic json, T Function(Map<String, dynamic>) parse) {
    final items = json is List ? json : (json is Map ? json['items'] as List? : null);
    return (items ?? const []).whereType<Map<String, dynamic>>().map(parse).toList();
  }

  Future<Uint8List?> fetchAvatar({void Function(Uint8List bytes)? onCached}) async {
    if (demoService.isDemoMode) return demoService.demoAvatar();
    const cacheKey = 'avatar';
    if (onCached != null) {
      final cached = await ApiCache.instance.readBytes(cacheKey, CacheTtl.long);
      if (cached != null) onCached(cached);
    }
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/hub/avatars/me'),
        headers: {'Cookie': cookie},
      );
      if (response.statusCode == 200) {
        unawaited(ApiCache.instance.writeBytes(cacheKey, response.bodyBytes));
        return response.bodyBytes;
      }
      if (response.statusCode == 404) {
        await ApiCache.instance.remove(cacheKey);
        return null;
      }
    } catch (_) {}
    return ApiCache.instance.readBytes(cacheKey, CacheTtl.long);
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
      final ok = response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
      if (ok) await ApiCache.instance.writeBytes('avatar', bytes);
      return ok;
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
      final ok = response.statusCode == 200 || response.statusCode == 204;
      if (ok) await ApiCache.instance.remove('avatar');
      return ok;
    } catch (_) {}
    return false;
  }

  Future<StudentProfile?> fetchProfile({void Function(StudentProfile profile)? onCached}) async {
    if (demoService.isDemoMode) return demoService.demoProfile();
    return _cachedGet(
      '/student-hub/students/me',
      maxAge: CacheTtl.long,
      parse: (json) => StudentProfile.fromJson(json),
      label: 'fetching profile',
      onCached: onCached,
    );
  }

  Future<List<StudentTask>?> fetchTasks({
    bool inProgress = true,
    bool review = false,
    bool backlog = true,
    bool failed = false,
    bool evaluated = false,
    void Function(List<StudentTask> tasks)? onCached,
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
    final states = <String>[];
    if (inProgress) states.addAll(['state=inProgress', 'state=submitted', 'state=reworking']);
    if (review) states.add('state=review');
    if (backlog) states.add('state=backlog');
    if (failed) states.add('state=failed');
    if (evaluated) states.add('state=evaluated');
    return _cachedGet(
      '/micro-lms/tasks/student?${states.join('&')}',
      maxAge: CacheTtl.short,
      parse: (json) => _parseList(json, StudentTask.fromJson),
      label: 'fetching tasks',
      onCached: onCached,
    );
  }

  Future<T?> _peekCache<T>(String path, Duration maxAge, T? Function(dynamic json) parse) async {
    final body = await ApiCache.instance.read(path, maxAge);
    if (body == null) return null;
    try {
      return parse(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }

  Future<CourseOverview?> cachedCourseOverview(int courseId) async {
    if (demoService.isDemoMode) return demoService.demoCourseOverview(courseId);
    return _peekCache(
      '/micro-lms/courses/$courseId/overview',
      CacheTtl.long,
      (json) => CourseOverview.fromJson(json),
    );
  }

  Future<QuizTask?> cachedQuizTask(int taskId) async {
    if (demoService.isDemoMode) return null;
    return _peekCache(
      '/micro-lms/tasks/$taskId',
      CacheTtl.short,
      (json) => json is Map<String, dynamic> ? QuizTask.fromJson(json) : null,
    );
  }

  Future<List<QuizPlayerQuestion>?> cachedQuizQuestions(int quizId) async {
    if (demoService.isDemoMode) return null;
    return _peekCache(
      '/micro-lms/quizzes/$quizId/questions',
      CacheTtl.long,
      (json) => _parseList(json, QuizPlayerQuestion.fromJson),
    );
  }

  Future<QuizAttempt?> cachedQuizAttempt(int attemptId) async {
    if (demoService.isDemoMode) return null;
    return _peekCache(
      '/micro-lms/quizzes/attempts/$attemptId',
      CacheTtl.short,
      (json) => json is Map<String, dynamic> ? QuizAttempt.fromJson(json) : null,
    );
  }

  Future<List<Course>> fetchCourses({void Function(List<Course> courses)? onCached}) async {
    if (demoService.isDemoMode) return demoService.demoCourses();
    final courses = await _cachedGet(
      '/micro-lms/courses/student?limit=10000',
      maxAge: CacheTtl.long,
      parse: (json) => _parseList(json, Course.fromJson),
      label: 'fetching courses',
      onCached: onCached,
    );
    return courses ?? [];
  }

  Future<List<Course>> fetchArchivedCourses({
    int pageSize = 20,
    void Function(List<Course> courses)? onCached,
  }) async {
    if (demoService.isDemoMode) {
      return demoService.demoCourses().where((c) => c.isArchived).toList();
    }
    const cacheKey = 'courses/archived';
    List<Course>? readCached(String? body) {
      if (body == null) return null;
      try {
        return _parseList(jsonDecode(body), Course.fromJson);
      } catch (_) {
        return null;
      }
    }

    if (onCached != null) {
      final cached = readCached(await ApiCache.instance.read(cacheKey, CacheTtl.long));
      if (cached != null) onCached(cached);
    }
    final items = await _fetchCoursesPaged(state: 'archived', pageSize: pageSize);
    if (items != null) {
      unawaited(ApiCache.instance.write(cacheKey, jsonEncode(items)));
      return items.map(Course.fromJson).toList();
    }
    return readCached(await ApiCache.instance.read(cacheKey, CacheTtl.long)) ?? [];
  }

  Future<List<Map<String, dynamic>>?> _fetchCoursesPaged({
    required String state,
    int pageSize = 20,
  }) async {
    final result = <Map<String, dynamic>>[];
    final seenIds = <Object?>{};
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

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
        if (response.statusCode != 200) return null;

        final data = jsonDecode(response.body);
        final page = (data is List ? data : (data is Map ? data['items'] as List? : null) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final fresh = page.where((c) => seenIds.add(c['id'])).toList();
        result.addAll(fresh);
        if (fresh.isEmpty || page.length < pageSize) break;
        offset += pageSize;
      }
    } catch (e, st) {
      _log.warning('Error fetching courses (state: $state)', e, st);
      return null;
    }
    return result;
  }



  Future<CourseOverview?> fetchCourseOverview(
    int courseId, {
    void Function(CourseOverview overview)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoCourseOverview(courseId);
    return _cachedGet(
      '/micro-lms/courses/$courseId/overview',
      maxAge: CacheTtl.long,
      parse: (json) => CourseOverview.fromJson(json),
      label: 'fetching course overview',
      onCached: onCached,
    );
  }

  Future<List<LongreadMaterial>> fetchLongreadMaterials(
    int longreadId, {
    void Function(List<LongreadMaterial> materials)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoLongreadMaterials(longreadId);
    final materials = await _cachedGet(
      '/micro-lms/longreads/$longreadId/materials?limit=10000',
      maxAge: CacheTtl.long,
      parse: (json) => _parseList(json, LongreadMaterial.fromJson),
      label: 'fetching longread materials',
      onCached: onCached,
    );
    return materials ?? [];
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

  Future<StudentLmsProfile?> fetchStudentLmsProfile({
    void Function(StudentLmsProfile profile)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoLmsProfile();
    return _cachedGet(
      '/micro-lms/students/me',
      maxAge: CacheTtl.short,
      parse: (json) => StudentLmsProfile.fromJson(json),
      label: 'fetching student LMS profile',
      onCached: onCached,
    );
  }

  Future<List<TaskEvent>> fetchTaskEvents(
    int taskId, {
    void Function(List<TaskEvent> events)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoTaskEvents(taskId);
    final events = await _cachedGet(
      '/micro-lms/tasks/$taskId/events',
      maxAge: CacheTtl.short,
      parse: (json) => _parseList(json, TaskEvent.fromJson),
      label: 'fetching task events',
      onCached: onCached,
    );
    return events ?? [];
  }

  Future<List<TaskComment>> fetchTaskComments(
    int taskId, {
    void Function(List<TaskComment> comments)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoTaskComments(taskId);
    final comments = await _cachedGet(
      '/micro-lms/tasks/$taskId/comments',
      maxAge: CacheTtl.short,
      parse: _parseComments,
      label: 'fetching task comments',
      onCached: onCached,
    );
    return comments ?? [];
  }

  static List<TaskComment> _parseComments(dynamic json) {
    final items = json is List ? json : (json is Map ? json['items'] as List? : null);
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

  Future<TaskDetails?> fetchTaskDetails(
    int taskId, {
    void Function(TaskDetails details)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoTaskDetails(taskId);
    return _cachedGet(
      '/micro-lms/tasks/$taskId',
      maxAge: CacheTtl.short,
      parse: (json) => json is Map<String, dynamic> ? TaskDetails.fromJson(json) : null,
      label: 'fetching task details',
      onCached: onCached,
    );
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
    return _cachedGet(
      '/micro-lms/tasks/$taskId',
      maxAge: CacheTtl.short,
      parse: (json) => json is Map<String, dynamic> ? QuizTask.fromJson(json) : null,
      label: 'fetching quiz task',
    );
  }

  Future<List<QuizPlayerQuestion>?> fetchQuizQuestions(int quizId) async {
    if (demoService.isDemoMode) return demoService.demoQuizQuestions(quizId);
    return _cachedGet(
      '/micro-lms/quizzes/$quizId/questions',
      maxAge: CacheTtl.long,
      parse: (json) => json is List ? _parseList(json, QuizPlayerQuestion.fromJson) : null,
      label: 'fetching quiz questions',
    );
  }

  Future<QuizAttempt?> fetchQuizAttempt(int attemptId) async {
    if (demoService.isDemoMode) return demoService.demoQuizAttempt(attemptId);
    return _cachedGet(
      '/micro-lms/quizzes/attempts/$attemptId',
      maxAge: CacheTtl.short,
      parse: (json) => json is Map<String, dynamic> ? QuizAttempt.fromJson(json) : null,
      label: 'fetching quiz attempt',
    );
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
    void Function(List<NotificationItem> items)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoNotifications(category);
    final items = await _cachedRequest(
      cacheKey: 'notifications/$category/$limit/$offset',
      maxAge: CacheTtl.short,
      send: (cookie) => http.post(
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
      ),
      parse: (json) => _parseList(json, NotificationItem.fromJson),
      label: 'fetching notifications',
      onCached: onCached,
    );
    return items ?? [];
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

  Future<StudentPerformanceResponse?> fetchStudentPerformance({
    void Function(StudentPerformanceResponse response)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoPerformance();
    return _cachedGet(
      '/micro-lms/performance/student',
      maxAge: CacheTtl.long,
      parse: (json) => StudentPerformanceResponse.fromJson(json),
      label: 'fetching student performance',
      onCached: onCached,
    );
  }

  Future<List<ActivityPerformance>?> fetchActivitiesPerformance(
    int courseId, {
    void Function(List<ActivityPerformance> items)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoActivitiesPerformance(courseId);
    return _cachedGet(
      '/micro-lms/courses/$courseId/activities-performance',
      maxAge: CacheTtl.long,
      parse: (json) => _parseList(json, ActivityPerformance.fromJson),
      label: 'fetching activities performance',
      onCached: onCached,
    );
  }

  Future<CourseExercisesResponse?> fetchCourseExercises(
    int courseId, {
    void Function(CourseExercisesResponse response)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoCourseExercises(courseId);
    return _cachedGet(
      '/micro-lms/courses/$courseId/exercises',
      maxAge: CacheTtl.long,
      parse: (json) => CourseExercisesResponse.fromJson(json),
      label: 'fetching course exercises',
      onCached: onCached,
    );
  }

  Future<CourseStudentPerformanceResponse?> fetchCourseStudentPerformance(
    int courseId, {
    void Function(CourseStudentPerformanceResponse response)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoCourseStudentPerformance(courseId);
    return _cachedGet(
      '/micro-lms/courses/$courseId/student-performance',
      maxAge: CacheTtl.long,
      parse: (json) => CourseStudentPerformanceResponse.fromJson(json),
      label: 'fetching course student performance',
      onCached: onCached,
    );
  }

  Future<GradebookResponse?> fetchGradebook({
    void Function(GradebookResponse response)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoGradebook();
    return _cachedGet(
      '/micro-lms/gradebook',
      maxAge: CacheTtl.long,
      parse: (json) => GradebookResponse.fromJson(json),
      label: 'fetching gradebook',
      onCached: onCached,
    );
  }

  Future<CourseProgress?> fetchCourseProgress(
    int courseId, {
    void Function(CourseProgress progress)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoCourseProgress(courseId);
    return _cachedGet(
      '/micro-lms/courses/$courseId/student/progress',
      maxAge: CacheTtl.long,
      parse: (json) => CourseProgress.fromJson(json),
      label: 'fetching course progress',
      onCached: onCached,
    );
  }

  Future<List<StudentTask>?> fetchDeadlines({
    int limit = 100,
    int? courseId,
    void Function(List<StudentTask> tasks)? onCached,
  }) async {
    if (demoService.isDemoMode) {
      return demoService.demoDeadlines(limit: limit, courseId: courseId);
    }
    final query = [
      'limit=$limit',
      if (courseId != null) 'courseId=$courseId',
    ].join('&');
    return _cachedGet(
      '/micro-lms/deadlines?$query',
      maxAge: CacheTtl.short,
      parse: (json) => _parseList(json, StudentTask.fromJson),
      label: 'fetching deadlines',
      onCached: onCached,
    );
  }

  Future<List<RecordingHost>> fetchRecordingHosts(
    int courseId, {
    void Function(List<RecordingHost> hosts)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoRecordingHosts(courseId);
    final hosts = await _cachedGet(
      '/micro-lms/calendar-events/recording-hosts?courseId=$courseId',
      maxAge: CacheTtl.long,
      parse: (json) => _parseList(json, RecordingHost.fromJson),
      label: 'fetching recording hosts',
      onCached: onCached,
    );
    return hosts ?? [];
  }

  Future<RecordingEventsPage?> fetchRecordingEvents({
    required int courseId,
    int offset = 0,
    int limit = 100,
    bool myEvents = true,
    Iterable<String> eventTypes = const [],
    Iterable<String> hostEmails = const [],
    void Function(RecordingEventsPage page)? onCached,
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
    final query = [
      'offset=$offset',
      'limit=$limit',
      'myEvents=$myEvents',
      ...eventTypes.map((t) => 'eventTypes=${Uri.encodeQueryComponent(t)}'),
      ...hostEmails.map((e) => 'hostEmails=${Uri.encodeQueryComponent(e)}'),
      'courseId=$courseId',
    ].join('&');
    return _cachedGet(
      '/micro-lms/calendar-events/recording-events?$query',
      maxAge: CacheTtl.long,
      parse: (json) {
        final items = _parseList(json, RecordingEvent.fromJson);
        final paging = json is Map ? json['paging'] : null;
        final total = paging is Map ? (paging['totalCount'] as num?)?.toInt() : null;
        return RecordingEventsPage(items: items, totalCount: total ?? items.length);
      },
      label: 'fetching recording events',
      onCached: onCached,
    );
  }

  Future<List<EventRecording>?> fetchEventRecordings(String eventId, String actualDate) async {
    if (demoService.isDemoMode) return demoService.demoEventRecordings(eventId);
    return _cachedGet(
      '/micro-lms/calendar-events/$eventId/recordings?actualDate=$actualDate',
      maxAge: CacheTtl.short,
      parse: (json) =>
          _parseList(json, EventRecording.fromJson).where((r) => r.url.isNotEmpty).toList(),
      label: 'fetching event recordings',
    );
  }

  Future<List<AttendanceCourse>?> fetchAttendanceCourses({
    bool archived = false,
    void Function(List<AttendanceCourse> courses)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoAttendanceCourses(archived: archived);
    return _cachedGet(
      '/micro-lms/v0/attendance/learn/courses?isArchived=$archived',
      maxAge: CacheTtl.short,
      parse: (json) => _parseList(json, AttendanceCourse.fromJson),
      label: 'fetching attendance courses',
      onCached: onCached,
    );
  }

  Future<List<AttendanceEvent>?> fetchCourseEventsByDate(
    int courseId,
    String date, {
    void Function(List<AttendanceEvent> events)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoCourseEventsByDate(courseId, date);
    return _cachedGet(
      '/micro-lms/calendar-events/learn/courses/$courseId/events/$date',
      maxAge: CacheTtl.long,
      parse: (json) => _parseList(json, AttendanceEvent.fromJson),
      label: 'fetching course events',
      onCached: onCached,
    );
  }

  Future<Set<String>?> fetchAttendedEventIds(
    int courseId,
    String date, {
    void Function(Set<String> ids)? onCached,
  }) async {
    if (demoService.isDemoMode) return demoService.demoAttendedEventIds(courseId, date);
    return _cachedGet(
      '/micro-lms/v0/attendance/learn/courses/$courseId/events/$date',
      maxAge: CacheTtl.short,
      parse: (json) => json is List ? json.map((e) => e.toString()).toSet() : null,
      label: 'fetching attended events',
      onCached: onCached,
    );
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
