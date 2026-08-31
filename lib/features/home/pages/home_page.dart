import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/app/route_observer.dart';
import 'package:cumobile/core/services/analytics_service.dart';
import 'package:cumobile/core/services/theme_service.dart';
import 'package:cumobile/features/home/native_tab_bar.dart';
import 'package:cumobile/features/home/widgets/late_days_dialog.dart';

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
import 'package:cumobile/core/services/demo_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/core/ui/app_dialogs.dart';
import 'package:cumobile/data/services/ical_service.dart';
import 'package:cumobile/features/home/widgets/sections/deadlines_section.dart';
import 'package:cumobile/features/home/widgets/sections/home_courses_section.dart';
import 'package:cumobile/features/home/widgets/sections/home_top_navigation.dart';
import 'package:cumobile/features/home/widgets/sections/schedule_section.dart';
import 'package:cumobile/features/home/widgets/tabs/courses_tab.dart';
import 'package:cumobile/features/home/widgets/tabs/files_tab.dart';
import 'package:cumobile/features/home/widgets/tabs/tasks_tab.dart';
import 'package:cumobile/features/home/pages/scan_work_page.dart';
import 'package:cumobile/features/performance/pages/course_performance_page.dart';
import 'package:cumobile/data/models/student_performance.dart';
import 'package:cumobile/features/settings/pages/file_rename_settings_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const HomePage({super.key, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  int _selectedTab = 0;
  bool _useNativeTabBar = false;
  double _nativeTabBarHeight = 0;
  StudentProfile? _profile;
  Uint8List? _avatarBytes;
  bool _isLoadingProfile = true;
  StudentLmsProfile? _lmsProfile;
  List<StudentTask> _tasks = [];
  bool _isLoadingTasks = true;
  bool _tasksError = false;
  final Set<int> _lateDaysLoadingIds = {};
  List<Course> _activeCourses = [];
  List<Course> _archivedCourses = [];
  bool _isLoadingCourses = true;
  final Set<String> _taskStatusFilters = {
    'backlog',
    'inProgress',
    'hasSolution',
    'revision',
    'review',
    'failed',
    'evaluated',
  };
  final Set<int> _taskCourseFilters = {};
  String _taskSearchQuery = '';
  static final Logger _log = Logger('HomePage');
  static const String _prefsActiveCoursesKey = 'courses_active_order';
  static const String _prefsArchivedCoursesKey = 'courses_archived_order';
  static const String _prefsIcsUrlKey = 'ics_url';
  static const String _prefsTaskStatusFiltersKey = 'tasks_status_filters';
  static const String _prefsTaskCourseFiltersKey = 'tasks_course_filters';
  static const String _prefsTaskSearchKey = 'tasks_search_query';
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
  List<StudentPerformanceCourse> _performanceCourses = [];
  bool _isLoadingPerformance = true;
  GradebookResponse? _gradebook;
  bool _isLoadingGradebook = true;

  @override
  void initState() {
    super.initState();
    Analytics.mainOpened();
    _initHome();
    _initNativeTabBar();
    ThemeController.instance.addListener(_syncNativeTabBarTheme);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (_useNativeTabBar) NativeTabBar.setVisible(visible: false);
  }

  @override
  void didPopNext() {
    if (_useNativeTabBar) NativeTabBar.setVisible(visible: true);
  }

  Future<void> _initNativeTabBar() async {
    if (!await NativeTabBar.isSupported()) return;
    NativeTabBar.setOnSelected(_onTabChanged);
    final height = await NativeTabBar.attach(selected: _selectedTab);
    if (!mounted || height == null) return;
    setState(() {
      _useNativeTabBar = true;
      _nativeTabBarHeight = height;
    });
  }

  void _syncNativeTabBarTheme() {
    if (_useNativeTabBar) NativeTabBar.syncTheme();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    ThemeController.instance.removeListener(_syncNativeTabBarTheme);
    if (_useNativeTabBar) {
      NativeTabBar.setOnSelected(null);
      NativeTabBar.detach();
    }
    _scheduleScrollController.dispose();
    super.dispose();
  }

  Future<void> _initHome() async {
    await _loadTaskFilters();
    await _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadProfile(),
      _loadTasks(),
      _loadCourses(),
      _loadLmsProfile(),
      _loadSchedule(),
      _loadPerformance(),
      _loadGradebook(),
    ]);
  }

  Future<void> _loadTaskFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStatuses = prefs.getStringList(_prefsTaskStatusFiltersKey);
    final savedCourses = prefs.getStringList(_prefsTaskCourseFiltersKey);
    final savedSearch = prefs.getString(_prefsTaskSearchKey);
    if (savedStatuses == null && savedCourses == null) return;
    setState(() {
      if (savedStatuses != null && savedStatuses.isNotEmpty) {
        _taskStatusFilters
          ..clear()
          ..addAll(savedStatuses);
      }
      if (savedCourses != null) {
        _taskCourseFilters
          ..clear()
          ..addAll(
            savedCourses.map(int.tryParse).whereType<int>(),
          );
      }
      if (savedSearch != null) {
        _taskSearchQuery = savedSearch;
      }
    });
  }

  Future<void> _saveTaskFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsTaskStatusFiltersKey,
      _taskStatusFilters.toList(),
    );
    await prefs.setStringList(
      _prefsTaskCourseFiltersKey,
      _taskCourseFilters.map((id) => id.toString()).toList(),
    );
    await prefs.setString(_prefsTaskSearchKey, _taskSearchQuery);
  }

  Future<void> _loadProfile() async {
    try {
      final results = await Future.wait([
        apiService.fetchProfile(),
        apiService.fetchAvatar(),
      ]);
      if (!mounted) return;
      final profile = results[0] as StudentProfile?;
      setState(() {
        _profile = profile;
        _avatarBytes = results[1] as Uint8List?;
        _isLoadingProfile = false;
      });
      if (profile != null) {
        Analytics.setCourseNumber(profile.course);
      }
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
        failed: true,
        evaluated: true,
      );
      if (!mounted) return;
      if (tasks == null) {
        setState(() {
          _isLoadingTasks = false;
          _tasksError = true;
        });
        return;
      }
      tasks.sort(_compareTasksByDeadline);
      setState(() {
        _tasks = tasks;
        _isLoadingTasks = false;
        _tasksError = false;
      });
    } catch (e, st) {
      _log.warning('Error loading tasks', e, st);
      if (!mounted) return;
      setState(() {
        _isLoadingTasks = false;
        _tasksError = true;
      });
    }
  }

  Future<void> _loadCourses() async {
    try {
      final responses = await Future.wait([
        apiService.fetchCourses(),
        apiService.fetchArchivedCourses(),
      ]);
      final fetchedCourses = responses[0];
      final apiArchivedCourses = responses[1];
      final courses = <int, Course>{
        for (final course in apiArchivedCourses) course.id: course,
        for (final course in fetchedCourses) course.id: course,
      }.values.toList();

      final prefs = await SharedPreferences.getInstance();
      final savedActiveOrder = prefs.getStringList(_prefsActiveCoursesKey);
      final savedArchivedOrder = prefs.getStringList(_prefsArchivedCoursesKey);
      final hasSavedArchived = savedArchivedOrder != null;
      final backendArchivedIds = <int>{
        ...fetchedCourses.where((c) => c.isArchived).map((c) => c.id),
        ...apiArchivedCourses.map((c) => c.id),
      };
      final localArchivedIds = (savedArchivedOrder ?? <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      final effectiveArchivedIds = hasSavedArchived
          ? {...backendArchivedIds, ...localArchivedIds}
          : backendArchivedIds;

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
      // Сохраняем обновленный список если бекенд архивировал курсы
      if (backendArchivedIds.isNotEmpty) {
        _saveCoursePreferences();
      }
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
      if (profile != null) {
        Analytics.setStudyLevel(profile.studyLevel);
      }
    } catch (e, st) {
      _log.warning('Error loading LMS profile', e, st);
    }
  }

  Future<void> _loadPerformance() async {
    try {
      final response = await apiService.fetchStudentPerformance();
      if (!mounted) return;
      setState(() {
        _performanceCourses = response?.courses ?? [];
        _isLoadingPerformance = false;
      });
    } catch (e, st) {
      _log.warning('Error loading performance', e, st);
      if (!mounted) return;
      setState(() => _isLoadingPerformance = false);
    }
  }

  Future<void> _loadGradebook() async {
    try {
      final response = await apiService.fetchGradebook();
      if (!mounted) return;
      setState(() {
        _gradebook = response;
        _isLoadingGradebook = false;
      });
    } catch (e, st) {
      _log.warning('Error loading gradebook', e, st);
      if (!mounted) return;
      setState(() => _isLoadingGradebook = false);
    }
  }

  Future<void> _loadSchedule({DateTime? day}) async {
    try {
      final targetDay = day ?? _scheduleDate;
      final prefs = await SharedPreferences.getInstance();
      final icsUrl = prefs.getString(_prefsIcsUrlKey);
      Analytics.setCalendarConnected(icsUrl != null && icsUrl.isNotEmpty);
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
      picked = await AppDialogs.pickDate(
        context,
        initial: _scheduleDate,
        minimum: DateTime.now().subtract(const Duration(days: 365)),
        maximum: DateTime.now().add(const Duration(days: 365)),
        title: 'Дата расписания',
      );
    } else {
      final c = AppColors.of(context);
      final brightness = Theme.of(context).brightness;
      picked = await showDatePicker(
        context: context,
        initialDate: _scheduleDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('ru', 'RU'),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: brightness == Brightness.dark
                ? ColorScheme.dark(primary: c.accent, surface: c.surface)
                : ColorScheme.light(primary: c.accent, surface: c.surface),
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

  Future<void> _logout({String from = 'profile'}) async {
    Analytics.authLogoutButtonPressed(from: from);
    await apiService.clearCookie();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final c = AppColors.of(context);
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
        label: 'Обучение',
      ),
      BottomNavigationBarItem(
        icon: Icon(isIos ? CupertinoIcons.folder : Icons.folder),
        label: 'Файлы',
      ),
    ];
    final tabBottomInset = _useNativeTabBar
        ? _nativeTabBarHeight + MediaQuery.of(context).padding.bottom
        : 0.0;
    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeTopNavigation(
          title: _currentTabTitle(),
          lmsProfile: _lmsProfile,
          profile: _profile,
          avatarBytes: _avatarBytes,
          isLoadingProfile: _isLoadingProfile,
          onOpenNotifications: _openNotifications,
          onOpenProfile: _openProfile,
        ),
        if (demoService.isDemoMode) _buildDemoBanner(),
        const SizedBox(height: 12),
        Expanded(child: _buildTabBody(tabBottomInset)),
      ],
    );
    if (isIos) {
      return CupertinoPageScaffold(
        backgroundColor: c.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: bodyContent),
              if (!_useNativeTabBar)
                MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      bottom:
                          math.max(0, MediaQuery.of(context).padding.bottom - 6),
                    ),
                    child: CupertinoTabBar(
                      currentIndex: _selectedTab,
                      backgroundColor: c.background,
                      activeColor: c.accent,
                      inactiveColor: c.iconSecondary,
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
      backgroundColor: c.background,
      body: SafeArea(child: bodyContent),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        backgroundColor: c.background,
        selectedItemColor: c.accent,
        unselectedItemColor: c.iconSecondary,
        onTap: _onTabChanged,
        items: navItems,
      ),
    );
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    if (_useNativeTabBar) NativeTabBar.setSelected(index);
    Analytics.mainTabPressed(tab: _tabAnalyticsName(index));
    if (index == 3 && _downloadedFiles.isEmpty) {
      _loadFiles();
    }
  }

  String _tabAnalyticsName(int index) {
    switch (index) {
      case 0:
        return 'main';
      case 1:
        return 'tasks';
      case 2:
        return 'learning';
      case 3:
        return 'files';
      default:
        return 'unknown';
    }
  }

  Widget _buildDemoBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2D2D00),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Color(0xFFFFD600)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Демо-режим: данные не настоящие',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFFD600),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _logout(from: 'demo_banner'),
            child: const Text(
              'Выйти',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFFD600),
                fontWeight: FontWeight.w600,
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
        return 'Обучение';
      case 3:
        return 'Файлы';
      default:
        return '';
    }
  }

  Future<void> _openProfile() async {
    if (_profile == null) return;
    Analytics.mainProfileCellPressed();
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => ProfilePage(
                profile: _profile!,
                avatarBytes: _avatarBytes,
                onLogout: _logout,
                onCalendarChanged: _refreshScheduleAfterCalendarChange,
                onAvatarChanged: (bytes) => setState(() => _avatarBytes = bytes),
              ),
            )
          : MaterialPageRoute(
              builder: (context) => ProfilePage(
                profile: _profile!,
                avatarBytes: _avatarBytes,
                onLogout: _logout,
                onCalendarChanged: _refreshScheduleAfterCalendarChange,
                onAvatarChanged: (bytes) => setState(() => _avatarBytes = bytes),
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
    Analytics.mainNotificationsButtonPressed();
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (context) => const NotificationsPage())
          : MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }

  Widget _buildTabBody(double bottomInset) {
    return IndexedStack(
      index: _selectedTab,
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeadlinesSection(
                key: ValueKey('deadlines_${_archivedCourses.map((c) => c.id).join(',')}'),
                tasks: _filteredTasksForHome(),
                isLoading: _isLoadingTasks,
                hasError: _tasksError,
                onOpenTask: (task) {
                  Analytics.mainDeadlineCellPressed(
                    taskStatus: task.normalizedState,
                    courseId: task.course.id,
                  );
                  _openTask(task, from: 'deadlines');
                },
                userArchivedCourseIds: _archivedCourses.map((c) => c.id).toSet(),
              ),
              const SizedBox(height: 24),
              ScheduleSection(
                date: _scheduleDate,
                classes: _calendarClasses,
                isLoading: _isLoadingSchedule,
                emptyMessage: _scheduleMessage,
                scrollController: _scheduleScrollController,
                onPreviousDay: () {
                  Analytics.mainScheduleDateChanged(type: 'prev');
                  _shiftScheduleDate(-1);
                },
                onNextDay: () {
                  Analytics.mainScheduleDateChanged(type: 'next');
                  _shiftScheduleDate(1);
                },
                onSelectDate: () {
                  Analytics.mainScheduleDateChanged(type: 'picker');
                  _selectScheduleDate();
                },
                onGoToToday: () {
                  Analytics.mainScheduleDateChanged(type: 'today');
                  _goToToday();
                },
                onOpenLink: (url) {
                  Analytics.mainScheduleClassLinkPressed();
                  _openCalendarLink(url);
                },
              ),
              const SizedBox(height: 24),
              HomeCoursesSection(
                courses: _activeCourses,
                isLoading: _isLoadingCourses,
                onOpenCourse: (course) {
                  Analytics.mainCourseCellPressed(
                    courseId: course.id,
                    courseCategory: course.categoryName,
                  );
                  _openCourse(course, from: 'main');
                },
              ),
              SizedBox(height: 24 + bottomInset),
            ],
          ),
        ),
        TasksTab(
          bottomInset: bottomInset,
          key: ValueKey('tasks_${_archivedCourses.map((c) => c.id).join(',')}'),
          tasks: _tasks,
          isLoading: _isLoadingTasks,
          hasError: _tasksError,
          statusFilters: _taskStatusFilters,
          onStatusFiltersChanged: (filters) {
            setState(() {
              _taskStatusFilters
                ..clear()
                ..addAll(filters);
            });
            _saveTaskFilters();
          },
          courseFilters: _taskCourseFilters,
          onCourseFiltersChanged: (filters) {
            setState(() {
              _taskCourseFilters
                ..clear()
                ..addAll(filters);
            });
            _saveTaskFilters();
          },
          searchQuery: _taskSearchQuery,
          onSearchQueryChanged: (value) {
            setState(() => _taskSearchQuery = value);
            _saveTaskFilters();
          },
          onOpenTask: _openTask,
          userArchivedCourseIds: _archivedCourses.map((c) => c.id).toSet(),
          lateDaysBalance: _lmsProfile?.lateDaysBalance ?? 0,
          lateDaysLoadingIds: _lateDaysLoadingIds,
          onExtendDeadline: _showLateDaysDialog,
          onCancelLateDays: _cancelLateDays,
        ),
        CoursesTab(
          bottomInset: bottomInset,
          activeCourses: _activeCourses,
          archivedCourses: _archivedCourses,
          isLoading: _isLoadingCourses,
          onOpenCourse: _openCourse,
          onReorderActive: _reorderActiveCourse,
          onArchive: _archiveCourse,
          onRestore: _restoreCourse,
          performanceCourses: _performanceCourses,
          isLoadingPerformance: _isLoadingPerformance,
          onOpenPerformanceCourse: _openPerformanceCourse,
          gradebook: _gradebook,
          isLoadingGradebook: _isLoadingGradebook,
        ),
        FilesTab(
          bottomInset: bottomInset,
          files: _downloadedFiles,
          isLoading: _isLoadingFiles,
          selectedFiles: _selectedFiles,
          onRefresh: _loadFiles,
          onOpenTemplates: _openFileRenameSettings,
          onStartScan: _openScanner,
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

  static const _bottomStates = {'evaluated', 'failed', 'rejected', 'review'};

  static int _compareTasksByDeadline(StudentTask a, StudentTask b) {
    final aBottom = _bottomStates.contains(a.normalizedState);
    final bBottom = _bottomStates.contains(b.normalizedState);
    if (aBottom != bBottom) return aBottom ? 1 : -1;

    final aDeadline = a.effectiveDeadline;
    final bDeadline = b.effectiveDeadline;
    if (aDeadline == null && bDeadline == null) return 0;
    if (aDeadline == null) return 1;
    if (bDeadline == null) return -1;
    return aDeadline.compareTo(bDeadline);
  }

  List<StudentTask> _filteredTasksForHome() {
    final query = _taskSearchQuery.trim().toLowerCase();
    return _tasks.where((task) {
      if (_taskCourseFilters.isNotEmpty &&
          !_taskCourseFilters.contains(task.course.id)) {
        return false;
      }
      if (query.isEmpty) return true;
      return task.exercise.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openTask(StudentTask task, {String from = 'tasks'}) async {
    Analytics.taskCardPressed(
      from: from,
      taskStatus: task.normalizedState,
      courseId: task.course.id,
    );
    if (!mounted) return;
    final accent = AppColors.of(context).accent;
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CupertinoAlertDialog(
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CupertinoActivityIndicator(
              radius: 14,
              color: accent,
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: accent),
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
            await Navigator.push(
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
            if (!mounted) return;
            setState(() => _isLoadingTasks = true);
            await Future.wait([_loadTasks(), _loadLmsProfile()]);
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
      AppDialogs.message(context, message: message);
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


  Future<void> _showLateDaysDialog(StudentTask task) async {
    final balance = _lmsProfile?.lateDaysBalance ?? 0;
    final result = await showLateDaysDialog(
      context: context,
      taskName: task.exercise.name,
      courseName: task.course.cleanName,
      deadline: task.effectiveDeadline,
      existingLateDays: task.lateDays ?? 0,
      lateDaysBalance: balance,
    );
    if (result == null || !mounted) return;
    Analytics.taskLateDaysExtendPressed(
      courseId: task.course.id,
      daysCount: result,
    );
    setState(() => _lateDaysLoadingIds.add(task.id));
    final success = await apiService.prolongLateDays(task.id, result);
    if (!mounted) return;
    if (success) {
      await Future.wait([_loadTasks(), _loadLmsProfile()]);
      if (mounted) setState(() => _lateDaysLoadingIds.remove(task.id));
    } else {
      setState(() => _lateDaysLoadingIds.remove(task.id));
      _showSnack('Не удалось перенести дедлайн');
    }
  }

  Future<void> _cancelLateDays(StudentTask task) async {
    if (!task.canCancelLateDays) {
      _showCancelBlockedInfo();
      return;
    }
    final confirmed = await _showCancelLateDaysConfirm();
    if (confirmed != true || !mounted) return;
    Analytics.taskLateDaysCancelPressed(courseId: task.course.id);
    setState(() => _lateDaysLoadingIds.add(task.id));
    final success = await apiService.cancelLateDays(task.id);
    if (!mounted) return;
    if (success) {
      await Future.wait([_loadTasks(), _loadLmsProfile()]);
      if (mounted) setState(() => _lateDaysLoadingIds.remove(task.id));
    } else {
      setState(() => _lateDaysLoadingIds.remove(task.id));
      _showSnack('Не удалось отменить перенос');
    }
  }

  void _showCancelBlockedInfo() {
    const message =
        'Невозможно отменить перенос дедлайна, так как осталось менее 24 часов.\n\n'
        'Если вы не сдадите работу, Late Days автоматически вернутся.';
    AppDialogs.message(context, message: message, okLabel: 'Понятно');
  }

  Future<bool> _showCancelLateDaysConfirm() {
    return AppDialogs.confirm(
      context,
      title: 'Отменить перенос дедлайна?',
      confirmLabel: 'Отменить',
      cancelLabel: 'Нет',
      destructive: true,
    );
  }

  void _openCourse(Course course, {String from = 'courses'}) {
    Analytics.courseOpened(
      from: from,
      courseId: course.id,
      courseCategory: course.categoryName,
    );
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (context) => CoursePage(course: course))
          : MaterialPageRoute(builder: (context) => CoursePage(course: course)),
    );
  }

  void _openPerformanceCourse(StudentPerformanceCourse course) {
    Analytics.performanceCourseCellPressed(courseId: course.id);
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => CoursePerformancePage(course: course))
          : MaterialPageRoute(
              builder: (context) => CoursePerformancePage(course: course)),
    );
  }

  void _openFileRenameSettings() {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (_) => const FileRenameSettingsPage())
          : MaterialPageRoute(builder: (_) => const FileRenameSettingsPage()),
    );
  }

  Future<void> _openScanner() async {
    if (!mounted) return;
    final created = await Navigator.push<bool>(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (context) => const ScanWorkPage())
          : MaterialPageRoute(builder: (context) => const ScanWorkPage()),
    );
    if (created == true) {
      await _loadFiles();
      if (mounted) {
        _showSnack('Скан сохранён в файлах');
      }
    }
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
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Удалить все файлы?',
      message:
          'Будет удалено ${_downloadedFiles.length} файлов. Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!confirmed) return;

    Analytics.filesDeleteAllConfirmed(filesCount: _downloadedFiles.length);
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
