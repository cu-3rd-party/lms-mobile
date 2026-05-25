import 'package:appmetrica_plugin/appmetrica_plugin.dart';

class Analytics {
  Analytics._();

  static Future<void> setStudyLevel(String? value) async {
    if (value == null || value.isEmpty) return;
    await AppMetrica.reportUserProfile(
      AppMetricaUserProfile([
        AppMetricaStringAttribute.withValue('studyLevel', value),
      ]),
    );
  }

  static Future<void> setCourseNumber(int? value) async {
    if (value == null || value <= 0) return;
    await AppMetrica.reportUserProfile(
      AppMetricaUserProfile([
        AppMetricaNumberAttribute.withValue('courseNumber', value.toDouble()),
      ]),
    );
  }

  static Future<void> setCalendarConnected(bool value) async {
    await AppMetrica.reportUserProfile(
      AppMetricaUserProfile([
        AppMetricaBooleanAttribute.withValue('calendarConnected', value),
      ]),
    );
  }

  static Future<void> appStarted() =>
      AppMetrica.reportEvent('app.started');

  static Future<void> authLoginButtonPressed() =>
      AppMetrica.reportEvent('auth.login.buttonPressed');

  static Future<void> authLoginSuccess() =>
      AppMetrica.reportEvent('auth.login.success');

  static Future<void> authDemoButtonPressed() =>
      AppMetrica.reportEvent('auth.demo.buttonPressed');

  static Future<void> authLogoutButtonPressed({required String from}) =>
      AppMetrica.reportEventWithMap('auth.logout.buttonPressed', {'from': from});

  static Future<void> mainOpened() =>
      AppMetrica.reportEvent('main.opened');

  static Future<void> mainTabPressed({required String tab}) =>
      AppMetrica.reportEventWithMap('main.tabPressed', {'tab': tab});

  static Future<void> mainProfileCellPressed() =>
      AppMetrica.reportEvent('main.profile.cellPressed');

  static Future<void> mainNotificationsButtonPressed() =>
      AppMetrica.reportEvent('main.notifications.buttonPressed');

  static Future<void> mainDeadlineCellPressed({
    required String taskStatus,
    required int courseId,
  }) =>
      AppMetrica.reportEventWithMap('main.deadline.cellPressed', {
        'taskStatus': taskStatus,
        'courseId': courseId,
      });

  static Future<void> mainCourseCellPressed({
    required int courseId,
    String? courseCategory,
  }) =>
      AppMetrica.reportEventWithMap('main.course.cellPressed', {
        'courseId': courseId,
        'courseCategory': ?courseCategory,
      });

  static Future<void> mainScheduleDateChanged({required String type}) =>
      AppMetrica.reportEventWithMap('main.schedule.dateChanged', {'type': type});

  static Future<void> mainScheduleClassLinkPressed() =>
      AppMetrica.reportEvent('main.schedule.classLinkPressed');

  static Future<void> tasksActiveOpened() =>
      AppMetrica.reportEvent('tasks.active.opened');

  static Future<void> tasksArchiveOpened() =>
      AppMetrica.reportEvent('tasks.archive.opened');

  static Future<void> tasksSearchUsed() =>
      AppMetrica.reportEvent('tasks.search.used');

  static Future<void> tasksStatusFilterChanged({required Set<String> statuses}) =>
      AppMetrica.reportEventWithMap('tasks.statusFilter.changed', {
        'statuses': statuses.toList(),
      });

  static Future<void> tasksCourseFilterChanged({required Set<int> courseIds}) =>
      AppMetrica.reportEventWithMap('tasks.courseFilter.changed', {
        'courseIds': courseIds.toList(),
      });

  static Future<void> tasksFiltersResetButtonPressed() =>
      AppMetrica.reportEvent('tasks.filtersReset.buttonPressed');

  static Future<void> taskCardPressed({
    required String from,
    required String taskStatus,
    required int courseId,
  }) =>
      AppMetrica.reportEventWithMap('task.cardPressed', {
        'from': from,
        'taskStatus': taskStatus,
        'courseId': courseId,
      });

  static Future<void> taskStartButtonPressed({required int courseId}) =>
      AppMetrica.reportEventWithMap('task.start.buttonPressed', {
        'courseId': courseId,
      });

  static Future<void> taskSolutionFileAttached({
    required int courseId,
    required String fileType,
  }) =>
      AppMetrica.reportEventWithMap('task.solution.fileAttached', {
        'courseId': courseId,
        'fileType': fileType,
      });

  static Future<void> taskSolutionSubmitPressed({
    required int courseId,
    required bool hasFile,
    required bool hasUrl,
  }) =>
      AppMetrica.reportEventWithMap('task.solution.submitPressed', {
        'courseId': courseId,
        'hasFile': hasFile,
        'hasUrl': hasUrl,
      });

  static Future<void> taskCommentFileAttached({
    required int courseId,
    required String fileType,
  }) =>
      AppMetrica.reportEventWithMap('task.comment.fileAttached', {
        'courseId': courseId,
        'fileType': fileType,
      });

  static Future<void> taskCommentSubmitPressed({
    required int courseId,
    required bool hasFile,
  }) =>
      AppMetrica.reportEventWithMap('task.comment.submitPressed', {
        'courseId': courseId,
        'hasFile': hasFile,
      });

  static Future<void> taskLateDaysExtendPressed({
    required int courseId,
    required int daysCount,
  }) =>
      AppMetrica.reportEventWithMap('task.lateDays.extendPressed', {
        'courseId': courseId,
        'daysCount': daysCount,
      });

  static Future<void> taskLateDaysCancelPressed({required int courseId}) =>
      AppMetrica.reportEventWithMap('task.lateDays.cancelPressed', {
        'courseId': courseId,
      });

  static Future<void> taskTabsTabPressed({required String tab}) =>
      AppMetrica.reportEventWithMap('task.tabs.tabPressed', {'tab': tab});

  static Future<void> learningCoursesOpened() =>
      AppMetrica.reportEvent('learning.courses.opened');

  static Future<void> learningGradesheetOpened() =>
      AppMetrica.reportEvent('learning.gradesheet.opened');

  static Future<void> learningRecordbookOpened() =>
      AppMetrica.reportEvent('learning.recordbook.opened');

  static Future<void> courseOpened({
    required String from,
    required int courseId,
    String? courseCategory,
  }) =>
      AppMetrica.reportEventWithMap('course.opened', {
        'from': from,
        'courseId': courseId,
        'courseCategory': ?courseCategory,
      });

  static Future<void> courseSearchUsed({required int courseId}) =>
      AppMetrica.reportEventWithMap('course.search.used', {'courseId': courseId});

  static Future<void> courseThemeCellPressed({
    required int courseId,
    required int themeId,
  }) =>
      AppMetrica.reportEventWithMap('course.theme.cellPressed', {
        'courseId': courseId,
        'themeId': themeId,
      });

  static Future<void> courseLongreadCellPressed({
    required int courseId,
    required int themeId,
    required int longreadId,
  }) =>
      AppMetrica.reportEventWithMap('course.longread.cellPressed', {
        'courseId': courseId,
        'themeId': themeId,
        'longreadId': longreadId,
      });

  static Future<void> courseExerciseCellPressed({
    required int courseId,
    required int themeId,
  }) =>
      AppMetrica.reportEventWithMap('course.exercise.cellPressed', {
        'courseId': courseId,
        'themeId': themeId,
      });

  static Future<void> longreadOpened({
    required String from,
    required int courseId,
    required int longreadId,
  }) =>
      AppMetrica.reportEventWithMap('longread.opened', {
        'from': from,
        'courseId': courseId,
        'longreadId': longreadId,
      });

  static Future<void> longreadSearchUsed({required int longreadId}) =>
      AppMetrica.reportEventWithMap('longread.search.used', {
        'longreadId': longreadId,
      });

  static Future<void> longreadFileCellPressed({required String fileType}) =>
      AppMetrica.reportEventWithMap('longread.file.cellPressed', {
        'fileType': fileType,
      });

  static Future<void> longreadAttachmentCellPressed({required String fileType}) =>
      AppMetrica.reportEventWithMap('longread.attachment.cellPressed', {
        'fileType': fileType,
      });

  static Future<void> longreadExternalLinkPressed({required String from}) =>
      AppMetrica.reportEventWithMap('longread.externalLinkPressed', {'from': from});

  static Future<void> longreadCodeCopyPressed() =>
      AppMetrica.reportEvent('longread.code.copyPressed');

  static Future<void> performanceCourseCellPressed({required int courseId}) =>
      AppMetrica.reportEventWithMap('performance.course.cellPressed', {
        'courseId': courseId,
      });

  static Future<void> performanceTabPressed({
    required String tab,
    required int courseId,
  }) =>
      AppMetrica.reportEventWithMap('performance.tabPressed', {
        'tab': tab,
        'courseId': courseId,
      });

  static Future<void> performanceActivityFilterChanged({
    required int courseId,
    required String activityType,
  }) =>
      AppMetrica.reportEventWithMap('performance.activityFilter.changed', {
        'courseId': courseId,
        'activityType': activityType,
      });

  static Future<void> recordbookSemesterCellPressed({
    required int semester,
    required int year,
  }) =>
      AppMetrica.reportEventWithMap('recordbook.semester.cellPressed', {
        'semester': semester,
        'year': year,
      });

  static Future<void> notificationsTabPressed({required String tab}) =>
      AppMetrica.reportEventWithMap('notifications.tabPressed', {'tab': tab});

  static Future<void> notificationLinkPressed({required String category}) =>
      AppMetrica.reportEventWithMap('notification.linkPressed', {
        'category': category,
      });

  static Future<void> notificationLongreadOpened({required int longreadId}) =>
      AppMetrica.reportEventWithMap('notification.longread.opened', {
        'longreadId': longreadId,
      });

  static Future<void> filesFileCellPressed({required String fileType}) =>
      AppMetrica.reportEventWithMap('files.file.cellPressed', {
        'fileType': fileType,
      });

  static Future<void> filesFileLongPressed({required String fileType}) =>
      AppMetrica.reportEventWithMap('files.file.longPressed', {
        'fileType': fileType,
      });

  static Future<void> filesFileDeletePressed({required String fileType}) =>
      AppMetrica.reportEventWithMap('files.file.deletePressed', {
        'fileType': fileType,
      });

  static Future<void> filesDeleteAllConfirmed({required int filesCount}) =>
      AppMetrica.reportEventWithMap('files.deleteAll.confirmed', {
        'filesCount': filesCount,
      });

  static Future<void> scannerOpened() =>
      AppMetrica.reportEvent('scanner.opened');

  static Future<void> scannerCameraButtonPressed() =>
      AppMetrica.reportEvent('scanner.camera.buttonPressed');

  static Future<void> scannerGalleryButtonPressed() =>
      AppMetrica.reportEvent('scanner.gallery.buttonPressed');

  static Future<void> scannerPageEditPressed() =>
      AppMetrica.reportEvent('scanner.page.editPressed');

  static Future<void> scannerPdfSaved({
    required int pagesCount,
    required bool compressed,
  }) =>
      AppMetrica.reportEventWithMap('scanner.pdf.saved', {
        'pagesCount': pagesCount,
        'compressed': compressed,
      });

  static Future<void> fileTemplatesOpened() =>
      AppMetrica.reportEvent('fileTemplates.opened');

  static Future<void> fileTemplatesAddButtonPressed() =>
      AppMetrica.reportEvent('fileTemplates.add.buttonPressed');

  static Future<void> fileTemplatesCreated({
    required int courseId,
    required String activityType,
    required String fileType,
  }) =>
      AppMetrica.reportEventWithMap('fileTemplates.created', {
        'courseId': courseId,
        'activityType': activityType,
        'fileType': fileType,
      });

  static Future<void> fileTemplatesDeletePressed({required String fileType}) =>
      AppMetrica.reportEventWithMap('fileTemplates.deletePressed', {
        'fileType': fileType,
      });

  static Future<void> profileAvatarUploadPressed() =>
      AppMetrica.reportEvent('profile.avatar.uploadPressed');

  static Future<void> profileAvatarDeletePressed() =>
      AppMetrica.reportEvent('profile.avatar.deletePressed');

  static Future<void> profileThemeChanged({required String theme}) =>
      AppMetrica.reportEventWithMap('profile.theme.changed', {'theme': theme});

  static Future<void> profileEmailCopyPressed() =>
      AppMetrica.reportEvent('profile.email.copyPressed');

  static Future<void> profileCalendarSavePressed({required String state}) =>
      AppMetrica.reportEventWithMap('profile.calendar.savePressed', {
        'state': state,
      });

  static Future<void> profileCalendarDisconnectPressed() =>
      AppMetrica.reportEvent('profile.calendar.disconnectPressed');

  static Future<void> profileCalendarGuidePressed() =>
      AppMetrica.reportEvent('profile.calendar.guidePressed');
}

String analyticsFileType(String pathOrName) {
  final dot = pathOrName.lastIndexOf('.');
  if (dot == -1 || dot == pathOrName.length - 1) return 'unknown';
  return pathOrName.substring(dot + 1).toLowerCase();
}
