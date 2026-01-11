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
import 'package:cumobile/data/services/caldav_service.dart';
import 'package:cumobile/features/home/widgets/sections/deadlines_section.dart';
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
  static const String _prefsCaldavEmailKey = 'caldav_email';
  static const String _prefsCaldavPasswordKey = 'caldav_password';
  final DateFormat _scheduleTimeFormat = DateFormat('HH:mm');
  final CaldavService _caldavService = CaldavService();
  List<ClassData> _calendarClasses = [];
  bool _isLoadingSchedule = true;
  String? _scheduleMessage;
  DateTime _scheduleDate = DateTime.now();
  bool _isFetchingSchedule = false;
  final Map<String, List<ClassData>> _scheduleCache = {};
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
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (e, st) {
      _log.warning('Error loading profile', e, st);
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
      setState(() {
        _tasks = tasks;
        _isLoadingTasks = false;
      });
    } catch (e, st) {
      _log.warning('Error loading tasks', e, st);
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
      setState(() {
        _activeCourses = orderedActive;
        _archivedCourses = orderedArchived;
        _isLoadingCourses = false;
      });
    } catch (e, st) {
      _log.warning('Error loading courses', e, st);
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
      final cacheKey = _scheduleCacheKey(targetDay);
      final cached = _scheduleCache[cacheKey];
      if (cached != null) {
      setState(() {
        _calendarClasses = cached;
        _isLoadingSchedule = false;
        _scheduleMessage = cached.isEmpty ? 'Нет занятий на этот день' : null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstEvent());
      return;
    }
      if (_isFetchingSchedule) return;
      _isFetchingSchedule = true;
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_prefsCaldavEmailKey);
      final password = prefs.getString(_prefsCaldavPasswordKey);
      if (email == null || password == null) {
        setState(() {
          _calendarClasses = [];
          _isLoadingSchedule = false;
          _scheduleMessage = 'Подключите календарь в профиле';
        });
        _isFetchingSchedule = false;
        return;
      }
      final events = await _caldavService.fetchEventsForDay(
        email: email,
        password: password,
        day: targetDay,
      );
      final classes = events.map(_eventToClassData).toList();
      classes.sort((a, b) => a.startTime.compareTo(b.startTime));
      _scheduleCache[cacheKey] = classes;
      setState(() {
        _calendarClasses = classes;
        _isLoadingSchedule = false;
        _scheduleMessage = classes.isEmpty ? 'Нет занятий на этот день' : null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstEvent());
      _isFetchingSchedule = false;
    } catch (e, st) {
      _log.warning('Error loading schedule', e, st);
      setState(() {
        _calendarClasses = [];
        _isLoadingSchedule = false;
        _scheduleMessage = 'Не удалось загрузить расписание';
      });
      _isFetchingSchedule = false;
    }
  }

  Future<void> _selectScheduleDate() async {
    final picked = await showDatePicker(
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
    if (picked == null) return;
    if (_isSameDay(picked, _scheduleDate)) return;
    setState(() {
      _scheduleDate = picked;
      _isLoadingSchedule = true;
    });
    await _loadSchedule(day: picked);
  }

  Future<void> _logout() async {
    await apiService.clearCookie();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final navItems = const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Главная',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.assignment),
        label: 'Задания',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.school),
        label: 'Курсы',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.folder),
        label: 'Файлы',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopNavigation(),
            const SizedBox(height: 12),
            Expanded(child: _buildTabBody()),
          ],
        ),
      ),
      bottomNavigationBar: isIos
          ? MediaQuery.removePadding(
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
            )
          : BottomNavigationBar(
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

  Widget _buildTopNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _currentTabTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (_lmsProfile != null) ...[
            Text(
              'Late Days: ${_lmsProfile!.lateDaysBalance}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            tooltip: 'Уведомления',
          ),
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _profile != null
                    ? const Color(0xFF00E676).withValues(alpha: 0.2)
                    : const Color(0xFF1E1E1E),
                border: Border.all(color: const Color(0xFF00E676), width: 2),
              ),
              child: Center(
                child: _isLoadingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E676),
                        ),
                      )
                    : _profile != null
                        ? Text(
                            '${_profile!.firstName[0]}${_profile!.lastName[0]}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E676),
                            ),
                          )
                        : Icon(Icons.person, color: Colors.grey[500], size: 20),
              ),
            ),
          ),
        ],
      ),
    );
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          profile: _profile!,
          onLogout: _logout,
          onCalendarChanged: _refreshScheduleAfterCalendarChange,
        ),
      ),
    );
    await _refreshScheduleAfterCalendarChange();
  }

  Future<void> _refreshScheduleAfterCalendarChange() async {
    _scheduleCache.clear();
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
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_selectedTab) {
      case 0:
        return SingleChildScrollView(
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
              _buildCoursesSection(),
              const SizedBox(height: 24),
            ],
          ),
        );
      case 1:
        return TasksTab(
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
        );
      case 2:
        return CoursesTab(
          activeCourses: _activeCourses,
          archivedCourses: _archivedCourses,
          isLoading: _isLoadingCourses,
          onOpenCourse: _openCourse,
          onReorderActive: _reorderActiveCourse,
          onArchive: _archiveCourse,
          onRestore: _restoreCourse,
        );
      case 3:
        return FilesTab(
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
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openTask(StudentTask task) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );

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
              MaterialPageRoute(
                builder: (context) => LongreadPage(
                  longread: longread,
                  themeColor: themeColor,
                  courseName: courseName,
                  themeName: theme.name,
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

  String _scheduleCacheKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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

  Widget _buildCoursesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Курсы',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_activeCourses.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_activeCourses.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingCourses)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          else if (_activeCourses.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.school, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Нет активных курсов',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: _activeCourses.length,
              itemBuilder: (context, index) => _buildCourseCard(_activeCourses[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.cleanName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getCategoryName(course.category),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: course.categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    course.categoryIcon,
                    size: 14,
                    color: course.categoryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoursePage(course: course),
      ),
    );
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'mathematics':
        return 'Математика';
      case 'development':
        return 'Разработка';
      case 'stem':
        return 'Наука';
      case 'general':
        return 'Общее';
      case 'withoutCategory':
      default:
        return 'Без категории';
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoadingFiles = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
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
    final confirmed = await showDialog<bool>(
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
    );
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
