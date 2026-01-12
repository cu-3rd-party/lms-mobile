import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/data/models/class_data.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_profile.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/features/course/pages/course_page.dart';
import 'package:cumobile/features/longread/pages/longread_page.dart';
import 'package:cumobile/features/notifications/pages/notifications_page.dart';
import 'package:cumobile/features/profile/pages/profile_page.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/data/services/ical_service.dart';
import 'package:cumobile/features/home/widgets/sections/deadlines_section.dart';
import 'package:cumobile/features/home/widgets/sections/home_courses_section.dart';
import 'package:cumobile/features/home/widgets/sections/home_top_navigation.dart';
import 'package:cumobile/features/home/widgets/sections/schedule_section.dart';
import 'package:cumobile/features/home/widgets/tabs/courses_tab.dart';
import 'package:cumobile/features/home/widgets/tabs/files_tab.dart';
import 'package:cumobile/features/home/widgets/tabs/tasks_tab.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const HomePage({super.key, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  StudentProfile? _profile;
  bool _isLoadingProfile = true;
  StudentLmsProfile? _lmsProfile;
  List<StudentTask> _tasks = [];
  bool _isLoadingTasks = true;
  List<Course> _activeCourses = [];
  List<Course> _archivedCourses = [];
  bool _isLoadingCourses = true;
  final Set<String> _taskStatusFilters = {'inProgress', 'review', 'backlog'};
  static final Logger _log = Logger('HomePage');
  static const String _prefsActiveCoursesKey = 'courses_active_order';
  static const String _prefsArchivedCoursesKey = 'courses_archived_order';
  static const String _prefsIcsUrlKey = 'ics_url';
  final DateFormat _scheduleTimeFormat = DateFormat('HH:mm');
  final IcalService _icalService = IcalService();
  List<ClassData> _calendarClasses = [];
  bool _isLoadingSchedule = true;
  String? _scheduleMessage;
  DateTime _scheduleDate = DateTime.now();
  final ScrollController _scheduleScrollController = ScrollController();
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoadingFiles = false;
  final Set<String> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadProfile(),
      _loadTasks(),
      _loadCourses(),
      _loadLmsProfile(),
      _loadSchedule(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await apiService.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (e, st) {
      _log.warning('Error loading profile', e, st);
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await apiService.fetchTasks(
        inProgress: true,
        review: true,
        backlog: true,
      );
      tasks.sort((a, b) {
        if (a.deadline == null && b.deadline == null) return 0;
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return a.deadline!.compareTo(b.deadline!);
      });
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoadingTasks = false;
      });
    } catch (e, st) {
      _log.warning('Error loading tasks', e, st);
      if (!mounted) return;
      setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await apiService.fetchCourses();
      final prefs = await SharedPreferences.getInstance();
      final savedActiveOrder = prefs.getStringList(_prefsActiveCoursesKey);
      final savedArchivedOrder = prefs.getStringList(_prefsArchivedCoursesKey);
      final hasSavedArchived = savedArchivedOrder != null;
      final archivedIds = (savedArchivedOrder ?? <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      final effectiveArchivedIds = hasSavedArchived
          ? archivedIds
          : courses.where((c) => c.isArchived).map((c) => c.id).toSet();
      final activeCourses =
          courses.where((c) => !effectiveArchivedIds.contains(c.id)).toList();
      final archivedCourses =
          courses.where((c) => effectiveArchivedIds.contains(c.id)).toList();
      final orderedActive = _applyCourseOrder(activeCourses, savedActiveOrder);
      final orderedArchived = _applyCourseOrder(archivedCourses, savedArchivedOrder);
      if (!mounted) return;
      setState(() {
        _activeCourses = orderedActive;
        _archivedCourses = orderedArchived;
        _isLoadingCourses = false;
      });
    } catch (e, st) {
      _log.warning('Error loading courses', e, st);
      if (!mounted) return;
      setState(() {
        _isLoadingCourses = false;
      });
    }
  }

  List<Course> _applyCourseOrder(List<Course> courses, List<String>? order) {
    if (order == null || order.isEmpty) return courses;
    final byId = {for (final course in courses) course.id: course};
    final ordered = <Course>[];
    for (final id in order) {
      final parsed = int.tryParse(id);
      if (parsed == null) continue;
      final course = byId.remove(parsed);
      if (course != null) ordered.add(course);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  Future<void> _saveCoursePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsActiveCoursesKey,
      _activeCourses.map((c) => c.id.toString()).toList(),
    );
    await prefs.setStringList(
      _prefsArchivedCoursesKey,
      _archivedCourses.map((c) => c.id.toString()).toList(),
    );
  }

  Future<void> _loadLmsProfile() async {
    try {
      final profile = await apiService.fetchStudentLmsProfile();
      if (!mounted) return;
      setState(() {
        _lmsProfile = profile;
      });
    } catch (e, st) {
      _log.warning('Error loading LMS profile', e, st);
    }
  }

  Future<void> _loadSchedule({DateTime? day}) async {
    try {
      final targetDay = day ?? _scheduleDate;
      final prefs = await SharedPreferences.getInstance();
      final icsUrl = prefs.getString(_prefsIcsUrlKey);
      if (icsUrl == null || icsUrl.isEmpty) {
        if (!mounted) return;
        setState(() {
          _calendarClasses = [];
          _isLoadingSchedule = false;
          _scheduleMessage = 'Подключите календарь в профиле';
        });
        return;
      }
      final events = await _icalService.fetchEventsForDay(
        icsUrl: icsUrl,
        day: targetDay,
        onUpdate: (updatedEvents) {
          if (!mounted) return;
          // Игнорируем обновление если пользователь уже переключил день
          if (!_isSameDay(targetDay, _scheduleDate)) return;
          final classes = updatedEvents.map(_eventToClassData).toList();
          classes.sort((a, b) => a.startTime.compareTo(b.startTime));
          setState(() {
            _calendarClasses = classes;
            _scheduleMessage = classes.isEmpty ? 'Нет занятий на этот день' : null;
          });
        },
      );
      // Игнорируем результат если пользователь уже переключил день
      if (!_isSameDay(targetDay, _scheduleDate)) return;
      final classes = events.map(_eventToClassData).toList();
      classes.sort((a, b) => a.startTime.compareTo(b.startTime));
      if (!mounted) return;
      setState(() {
        _calendarClasses = classes;
        _isLoadingSchedule = false;
        _scheduleMessage = classes.isEmpty ? 'Нет занятий на этот день' : null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstEvent());
    } catch (e, st) {
      _log.warning('Error loading schedule', e, st);
      if (!mounted) return;
      setState(() {
        _calendarClasses = [];
        _isLoadingSchedule = false;
        _scheduleMessage = 'Не удалось загрузить расписание';
      });
    }
  }

  Future<void> _selectScheduleDate() async {
    DateTime? picked;
    if (Platform.isIOS) {
      picked = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (context) {
          var tempDate = _scheduleDate;
          return CupertinoPopupSurface(
            child: Container(
              height: 320,
              color: const Color(0xFF121212),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                        CupertinoButton(
                          onPressed: () => Navigator.pop(context, tempDate),
                          child: const Text('Готово'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _scheduleDate,
                      minimumDate: DateTime.now().subtract(const Duration(days: 365)),
                      maximumDate: DateTime.now().add(const Duration(days: 365)),
                      onDateTimeChanged: (value) => tempDate = value,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: _scheduleDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('ru', 'RU'),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E676),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        ),
      );
    }
    if (picked == null) return;
    final selectedDate = picked;
    if (_isSameDay(selectedDate, _scheduleDate)) return;
    setState(() {
      _scheduleDate = selectedDate;
      _isLoadingSchedule = true;
    });
    await _loadSchedule(day: selectedDate);
  }

  Future<void> _logout() async {
    await apiService.clearCookie();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final navItems = [
      BottomNavigationBarItem(
        icon: Icon(isIos ? CupertinoIcons.house : Icons.home),
        label: 'Главная',
      ),
      BottomNavigationBarItem(
        icon: Icon(isIos ? CupertinoIcons.square_list : Icons.assignment),
        label: 'Задания',
      ),
      BottomNavigationBarItem(
        icon: Icon(isIos ? CupertinoIcons.book : Icons.school),
        label: 'Курсы',
      ),
      BottomNavigationBarItem(
        icon: Icon(isIos ? CupertinoIcons.folder : Icons.folder),
        label: 'Файлы',
      ),
    ];
    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeTopNavigation(
          title: _currentTabTitle(),
          lmsProfile: _lmsProfile,
          profile: _profile,
          isLoadingProfile: _isLoadingProfile,
          onOpenNotifications: _openNotifications,
          onOpenProfile: _openProfile,
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildTabBody()),
      ],
    );
    if (isIos) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: bodyContent),
              MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 6,
                    bottom: math.max(0, MediaQuery.of(context).padding.bottom - 6),
                  ),
                  child: CupertinoTabBar(
                    currentIndex: _selectedTab,
                    backgroundColor: const Color(0xFF121212),
                    activeColor: const Color(0xFF00E676),
                    inactiveColor: Colors.grey[500]!,
                    onTap: _onTabChanged,
                    items: navItems,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: bodyContent),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF00E676),
        unselectedItemColor: Colors.grey[500],
        onTap: _onTabChanged,
        items: navItems,
      ),
    );
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    if (index == 3 && _downloadedFiles.isEmpty) {
      _loadFiles();
    }
  }

  String _currentTabTitle() {
    switch (_selectedTab) {
      case 0:
        return 'Главная';
      case 1:
        return 'Задания';
      case 2:
        return 'Курсы';
      case 3:
        return 'Файлы';
      default:
        return '';
    }
  }

  Future<void> _openProfile() async {
    if (_profile == null) return;
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => ProfilePage(
                profile: _profile!,
                onLogout: _logout,
                onCalendarChanged: _refreshScheduleAfterCalendarChange,
              ),
            )
          : MaterialPageRoute(
              builder: (context) => ProfilePage(
                profile: _profile!,
                onLogout: _logout,
                onCalendarChanged: _refreshScheduleAfterCalendarChange,
              ),
            ),
    );
  }

  Future<void> _refreshScheduleAfterCalendarChange() async {
    await _icalService.clearCache();
    if (!mounted) return;
    setState(() {
      _isLoadingSchedule = true;
      _scheduleMessage = null;
    });
    await _loadSchedule(day: _scheduleDate);
  }

  void _openNotifications() {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (context) => const NotificationsPage())
          : MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }

  Widget _buildTabBody() {
    return IndexedStack(
      index: _selectedTab,
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeadlinesSection(
                tasks: _tasks,
                isLoading: _isLoadingTasks,
              ),
              const SizedBox(height: 24),
              ScheduleSection(
                date: _scheduleDate,
                classes: _calendarClasses,
                isLoading: _isLoadingSchedule,
                emptyMessage: _scheduleMessage,
                scrollController: _scheduleScrollController,
                onPreviousDay: () => _shiftScheduleDate(-1),
                onNextDay: () => _shiftScheduleDate(1),
                onSelectDate: _selectScheduleDate,
                onGoToToday: _goToToday,
                onOpenLink: _openCalendarLink,
              ),
              const SizedBox(height: 24),
              HomeCoursesSection(
                courses: _activeCourses,
                isLoading: _isLoadingCourses,
                onOpenCourse: _openCourse,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        TasksTab(
          tasks: _tasks,
          isLoading: _isLoadingTasks,
          statusFilters: _taskStatusFilters,
          onStatusFiltersChanged: (filters) {
            setState(() {
              _taskStatusFilters
                ..clear()
                ..addAll(filters);
            });
          },
          onOpenTask: _openTask,
        ),
        CoursesTab(
          activeCourses: _activeCourses,
          archivedCourses: _archivedCourses,
          isLoading: _isLoadingCourses,
          onOpenCourse: _openCourse,
          onReorderActive: _reorderActiveCourse,
          onArchive: _archiveCourse,
          onRestore: _restoreCourse,
        ),
        FilesTab(
          files: _downloadedFiles,
          isLoading: _isLoadingFiles,
          selectedFiles: _selectedFiles,
          onRefresh: _loadFiles,
          onDeleteAll: _deleteAllFiles,
          onDeleteSelected: _deleteSelectedFiles,
          onDelete: _deleteFile,
          onToggleSelection: (path) {
            setState(() {
              if (_selectedFiles.contains(path)) {
                _selectedFiles.remove(path);
              } else {
                _selectedFiles.add(path);
              }
            });
          },
        ),
      ],
    );
  }

  Future<void> _openTask(StudentTask task) async {
    if (!mounted) return;
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CupertinoAlertDialog(
          content: Padding(
            padding: EdgeInsets.only(top: 8),
            child: CupertinoActivityIndicator(
              radius: 14,
              color: Color(0xFF00E676),
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    try {
      final overview = await apiService.fetchCourseOverview(task.course.id);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (overview == null) {
        _showSnack('Не удалось загрузить курс');
        return;
      }

      for (final theme in overview.themes) {
        for (final longread in theme.longreads) {
          final match = longread.exercises.any((ex) => ex.id == task.exercise.id);
          if (match) {
            final course = _findCourse(task.course.id);
            final themeColor = course?.categoryColor ?? const Color(0xFF607D8B);
            final courseName = course?.cleanName ?? task.course.cleanName;
            Navigator.push(
              context,
              Platform.isIOS
                  ? CupertinoPageRoute(
                      builder: (context) => LongreadPage(
                        longread: longread,
                        themeColor: themeColor,
                        courseName: courseName,
                        themeName: theme.name,
                        courseId: task.course.id,
                        themeId: theme.id,
                        selectedTaskId: task.id,
                      ),
                    )
                  : MaterialPageRoute(
                      builder: (context) => LongreadPage(
                        longread: longread,
                        themeColor: themeColor,
                        courseName: courseName,
                        themeName: theme.name,
                        courseId: task.course.id,
                        themeId: theme.id,
                        selectedTaskId: task.id,
                      ),
                    ),
            );
            return;
          }
        }
      }

      _showSnack('Задание не найдено в курсе');
    } catch (e, st) {
      _log.warning('Error opening task', e, st);
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack('Не удалось открыть задание');
    }
  }

  Course? _findCourse(int courseId) {
    for (final course in _activeCourses) {
      if (course.id == courseId) return course;
    }
    for (final course in _archivedCourses) {
      if (course.id == courseId) return course;
    }
    return null;
  }

  void _showSnack(String message) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _reorderActiveCourse(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _activeCourses.removeAt(oldIndex);
      _activeCourses.insert(newIndex, item);
    });
    _saveCoursePreferences();
  }

  void _archiveCourse(Course course) {
    setState(() {
      _activeCourses.removeWhere((c) => c.id == course.id);
      _archivedCourses.insert(0, course);
    });
    _saveCoursePreferences();
  }

  void _restoreCourse(Course course) {
    setState(() {
      _archivedCourses.removeWhere((c) => c.id == course.id);
      _activeCourses.add(course);
    });
    _saveCoursePreferences();
  }

  ClassData _eventToClassData(CalendarEvent event) {
    final roomMatch = RegExp(r'\\b[FB]\\d{3}\\b').firstMatch(event.summary);
    final room = roomMatch?.group(0) ?? '—';
    var title = event.summary;
    if (roomMatch != null) {
      title = title.replaceAll(roomMatch.group(0)!, '').trim();
    }
    return ClassData(
      startTime: _scheduleTimeFormat.format(event.start),
      endTime: _scheduleTimeFormat.format(event.end),
      room: room,
      type: '',
      title: title.isEmpty ? 'Занятие' : title,
      link: event.link,
    );
  }

  Future<void> _shiftScheduleDate(int deltaDays) async {
    final next = _scheduleDate.add(Duration(days: deltaDays));
    setState(() {
      _scheduleDate = next;
      _isLoadingSchedule = true;
    });
    await _loadSchedule(day: next);
  }

  Future<void> _goToToday() async {
    final today = DateTime.now();
    if (_isSameDay(today, _scheduleDate)) return;
    setState(() {
      _scheduleDate = today;
      _isLoadingSchedule = true;
    });
    await _loadSchedule(day: today);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scrollToFirstEvent() {
    if (!_scheduleScrollController.hasClients) return;
    final now = DateTime.now();
    const hourHeight = 80.0;
    if (_isSameDay(_scheduleDate, now)) {
      final nowOffset = ((now.hour * 60 + now.minute) / 60.0) * hourHeight;
      final target = (nowOffset - 20)
          .clamp(0.0, _scheduleScrollController.position.maxScrollExtent.toDouble());
      _scheduleScrollController.animateTo(
        target.toDouble(),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_calendarClasses.isEmpty) {
      _scheduleScrollController.jumpTo(0);
      return;
    }
    final first = _calendarClasses.first;
    final parts = first.startTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final offset = ((hour * 60 + minute) / 60.0) * hourHeight;
    final target =
        (offset - 20).clamp(0.0, _scheduleScrollController.position.maxScrollExtent.toDouble());
    _scheduleScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openCalendarLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }


  void _openCourse(Course course) {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (context) => CoursePage(course: course))
          : MaterialPageRoute(builder: (context) => CoursePage(course: course)),
    );
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoadingFiles = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => !f.path.endsWith('calendar_cache.ics'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      setState(() {
        _downloadedFiles = files;
        _isLoadingFiles = false;
      });
    } catch (e, st) {
      _log.warning('Error loading files', e, st);
      setState(() => _isLoadingFiles = false);
    }
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      _selectedFiles.remove(file.path);
      await _loadFiles();
    } catch (e, st) {
      _log.warning('Error deleting file', e, st);
    }
  }

  Future<void> _deleteSelectedFiles() async {
    final filesToDelete = _selectedFiles.toList();
    for (final path in filesToDelete) {
      try {
        await File(path).delete();
      } catch (e) {
        _log.warning('Error deleting file: $path');
      }
    }
    _selectedFiles.clear();
    await _loadFiles();
  }

  Future<void> _deleteAllFiles() async {
    final confirmed = await (Platform.isIOS
        ? showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Удалить все файлы?'),
              content: Text(
                'Будет удалено ${_downloadedFiles.length} файлов. Это действие нельзя отменить.',
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context, true),
                  isDestructiveAction: true,
                  child: const Text('Удалить'),
                ),
              ],
            ),
          )
        : showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Удалить все файлы?', style: TextStyle(color: Colors.white)),
              content: Text(
                'Будет удалено ${_downloadedFiles.length} файлов. Это действие нельзя отменить.',
                style: TextStyle(color: Colors.grey[400]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ));
    if (confirmed != true) return;

    for (final file in _downloadedFiles) {
      try {
        await file.delete();
      } catch (e) {
        _log.warning('Error deleting file: ${file.path}');
      }
    }
    _selectedFiles.clear();
    await _loadFiles();
  }

}
