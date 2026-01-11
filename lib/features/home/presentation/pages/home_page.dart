import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/data/models/class_data.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_profile.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/features/course/presentation/pages/course_page.dart';
import 'package:cumobile/features/longread/presentation/pages/longread_page.dart';
import 'package:cumobile/features/notifications/presentation/pages/notifications_page.dart';
import 'package:cumobile/features/profile/presentation/pages/profile_page.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/data/services/caldav_service.dart';

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
  bool _isEditingCourses = false;
  static final Logger _log = Logger('HomePage');
  static const String _prefsActiveCoursesKey = 'courses_active_order';
  static const String _prefsArchivedCoursesKey = 'courses_archived_order';
  static const String _prefsCaldavEmailKey = 'caldav_email';
  static const String _prefsCaldavPasswordKey = 'caldav_password';
  final DateFormat _scheduleDateFormat = DateFormat('d MMMM (EEE)', 'ru_RU');
  final DateFormat _scheduleTimeFormat = DateFormat('HH:mm');
  final CaldavService _caldavService = CaldavService();
  List<ClassData> _calendarClasses = [];
  bool _isLoadingSchedule = true;
  String? _scheduleMessage;
  DateTime _scheduleDate = DateTime.now();
  bool _isFetchingSchedule = false;
  final Map<String, List<ClassData>> _scheduleCache = {};
  final ScrollController _scheduleScrollController = ScrollController();

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
                  onTap: (index) => setState(() => _selectedTab = index),
                  items: navItems,
                ),
              ),
            )
          : BottomNavigationBar(
              currentIndex: _selectedTab,
              backgroundColor: const Color(0xFF121212),
              selectedItemColor: const Color(0xFF00E676),
              unselectedItemColor: Colors.grey[500],
              onTap: (index) => setState(() => _selectedTab = index),
              items: navItems,
            ),
    );
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
              _buildDeadlinesSection(),
              const SizedBox(height: 24),
              _buildScheduleSection(),
              const SizedBox(height: 24),
              _buildCoursesSection(),
              const SizedBox(height: 24),
            ],
          ),
        );
      case 1:
        return _buildTasksTab();
      case 2:
        return _buildCoursesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDeadlinesSection() {
    final deadlineTasks = _tasks.where((task) => task.state != 'review').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Дедлайны',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (deadlineTasks.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${deadlineTasks.length}',
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
        ),
        const SizedBox(height: 12),
        if (_isLoadingTasks)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            ),
          )
        else if (deadlineTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Нет активных заданий',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: deadlineTasks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final task = deadlineTasks[index];
                return _buildTaskCard(task);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTaskCard(StudentTask task) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: task.isOverdue
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: task.stateColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(task.typeIcon, color: task.stateColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  task.course.cleanName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.deadline != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: task.isOverdue ? Colors.redAccent : Colors.grey[400],
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          task.formattedDeadline,
                          style: TextStyle(
                            fontSize: 10,
                            color: task.isOverdue ? Colors.redAccent : Colors.grey[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: task.stateColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStateLabel(task.state),
                          style: TextStyle(
                            fontSize: 9,
                            color: task.stateColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'макс. ${task.exercise.maxScore}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStateLabel(String state) {
    switch (state) {
      case 'inProgress':
        return 'В работе';
      case 'review':
        return 'На проверке';
      case 'backlog':
        return 'Не начато';
      default:
        return state;
    }
  }

  Widget _buildScheduleSection() {
    const double hourHeight = 80.0;
    final classes = _calendarClasses;
    final now = _scheduleDate;
    if (_isLoadingSchedule) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }
    if (classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScheduleHeader(now),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _scheduleMessage ?? 'Нет занятий на сегодня',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    const minHour = 0;
    const maxHour = 23;
    final timeSlots = [
      for (var h = minHour; h <= maxHour; h++) '${h.toString().padLeft(2, '0')}:00'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScheduleHeader(now),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: SingleChildScrollView(
              controller: _scheduleScrollController,
              child: SizedBox(
                height: timeSlots.length * hourHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Column(
                      children: [
                        ...timeSlots.map((time) {
                          return SizedBox(
                            height: hourHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    height: 1,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    ...classes.map((classData) {
                      final startParts = classData.startTime.split(':');
                      final endParts = classData.endTime.split(':');
                      final startHour = int.parse(startParts[0]);
                      final startMinute = int.parse(startParts[1]);
                      final endHour = int.parse(endParts[0]);
                      final endMinute = int.parse(endParts[1]);

                      final startTimeInMinutes = startHour * 60 + startMinute;
                      final endTimeInMinutes = endHour * 60 + endMinute;
                      final durationInMinutes = endTimeInMinutes - startTimeInMinutes;

                      const baseTimeInMinutes = minHour * 60;
                      final topOffset =
                          (startTimeInMinutes - baseTimeInMinutes) / 60.0 * hourHeight;
                      final calculatedHeight = durationInMinutes / 60.0 * hourHeight;
                      final height = (calculatedHeight < 70 ? 70.0 : calculatedHeight).toDouble();

                      return Positioned(
                        left: 50.0,
                        right: 0.0,
                        top: topOffset,
                        height: height,
                        child: _buildClassCard(classData),
                      );
                    }),
                    if (_isSameDay(now, DateTime.now()))
                      _buildNowIndicator(
                        now: DateTime.now(),
                        hourHeight: hourHeight,
                        leftOffset: 50,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_isLoadingTasks) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    final filtered = _filteredTasks();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildTaskFilters(),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Text(
                  'Нет заданий по выбранным фильтрам',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...filtered.map(_buildTaskListItem),
      ],
    );
  }

  Widget _buildTaskFilters() {
    final counts = _taskCountsByState();
    return Row(
      children: [
        Expanded(
          child: _buildStatusDropdown(counts),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown(Map<String, int> counts) {
    return GestureDetector(
      onTap: () => _openStatusSheet(counts),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list, color: Colors.grey[500], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedStatusLabel(),
                style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _openStatusSheet(Map<String, int> counts) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Фильтр по статусу',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusTile(
                    'В работе',
                    'inProgress',
                    counts['inProgress'] ?? 0,
                    setLocalState,
                  ),
                  _buildStatusTile(
                    'На проверке',
                    'review',
                    counts['review'] ?? 0,
                    setLocalState,
                  ),
                  _buildStatusTile(
                    'Не начато',
                    'backlog',
                    counts['backlog'] ?? 0,
                    setLocalState,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusTile(
    String label,
    String state,
    int count,
    void Function(void Function()) setLocalState,
  ) {
    final isSelected = _taskStatusFilters.contains(state);
    return CheckboxListTile(
      value: isSelected,
      dense: true,
      activeColor: const Color(0xFF00E676),
      checkColor: Colors.black,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        '$label ($count)',
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
      onChanged: (value) {
        setState(() {
          if (isSelected) {
            _taskStatusFilters.remove(state);
          } else {
            _taskStatusFilters.add(state);
          }
          if (_taskStatusFilters.isEmpty) {
            _taskStatusFilters
              ..add('inProgress')
              ..add('review')
              ..add('backlog');
          }
        });
        setLocalState(() {});
      },
    );
  }

  String _selectedStatusLabel() {
    final mapping = {
      'inProgress': 'В работе',
      'review': 'На проверке',
      'backlog': 'Не начато',
    };
    final labels = _taskStatusFilters.map((s) => mapping[s] ?? s).toList();
    labels.sort();
    return labels.isEmpty ? 'Статусы' : 'Статусы: ${labels.join(', ')}';
  }

  List<StudentTask> _filteredTasks() {
    final filters = _taskStatusFilters;
    return _tasks.where((task) => filters.contains(task.state)).toList();
  }

  Map<String, int> _taskCountsByState() {
    final counts = <String, int>{
      'inProgress': 0,
      'review': 0,
      'backlog': 0,
    };
    for (final task in _tasks) {
      if (counts.containsKey(task.state)) {
        counts[task.state] = counts[task.state]! + 1;
      }
    }
    return counts;
  }

  Widget _buildTaskListItem(StudentTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: task.isOverdue
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: InkWell(
        onTap: () => _openTask(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: task.stateColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(task.typeIcon, color: task.stateColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.exercise.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.course.cleanName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: task.stateColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStateLabel(task.state),
                            style: TextStyle(
                              fontSize: 10,
                              color: task.stateColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (task.deadline != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: task.isOverdue ? Colors.redAccent : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.formattedDeadline,
                            style: TextStyle(
                              fontSize: 11,
                              color: task.isOverdue ? Colors.redAccent : Colors.grey[500],
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          'макс. ${task.exercise.maxScore}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildCoursesTab() {
    if (_isLoadingCourses) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          children: [
            const Text(
              'Активные курсы',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _isEditingCourses = !_isEditingCourses),
              icon: Icon(
                _isEditingCourses ? Icons.check : Icons.edit,
                size: 16,
                color: const Color(0xFF00E676),
              ),
              label: Text(
                _isEditingCourses ? 'Готово' : 'Редактировать',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_activeCourses.isEmpty)
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
        else if (_isEditingCourses)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _reorderActiveCourse,
            buildDefaultDragHandles: false,
            itemCount: _activeCourses.length,
            itemBuilder: (context, index) {
              final course = _activeCourses[index];
              return _buildCourseListTile(
                course,
                key: ValueKey('active-${course.id}'),
                onTap: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'В архив',
                      icon: Icon(Icons.archive, color: Colors.grey[500], size: 20),
                      onPressed: () => _archiveCourse(course),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.drag_handle, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          )
        else
          ..._activeCourses.map(
            (course) => _buildCourseListTile(
              course,
              key: ValueKey('active-${course.id}'),
              onTap: () => _openCourse(course),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Архив',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '${_archivedCourses.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_archivedCourses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.archive, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Text(
                  'Архив пуст',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          )
        else
          ..._archivedCourses.map(
            (course) => _buildCourseListTile(
              course,
              key: ValueKey('archived-${course.id}'),
              onTap: _isEditingCourses ? null : () => _openCourse(course),
              trailing: _isEditingCourses
                  ? IconButton(
                      tooltip: 'Вернуть',
                      icon: Icon(Icons.unarchive, color: Colors.grey[500], size: 20),
                      onPressed: () => _restoreCourse(course),
                    )
                  : Icon(Icons.chevron_right, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildCourseListTile(
    Course course, {
    required Key key,
    required VoidCallback? onTap,
    required Widget trailing,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: course.categoryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  course.categoryIcon,
                  size: 16,
                  color: course.categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.cleanName,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCategoryName(course.category),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
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

  Widget _buildScheduleHeader(DateTime date) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Расписание',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _scheduleDateFormat.format(date).toLowerCase(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        if (!isToday) ...[
          TextButton(
            onPressed: _goToToday,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: const Color(0xFF00E676),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Сегодня',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
        ],
        _navIconButton(
          icon: Icons.chevron_left,
          tooltip: 'Предыдущий день',
          onTap: () => _shiftScheduleDate(-1),
        ),
        const SizedBox(width: 4),
        _navIconButton(
          icon: Icons.calendar_today,
          tooltip: 'Выбрать дату',
          onTap: _selectScheduleDate,
          size: 18,
        ),
        const SizedBox(width: 4),
        _navIconButton(
          icon: Icons.chevron_right,
          tooltip: 'Следующий день',
          onTap: () => _shiftScheduleDate(1),
        ),
      ],
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

  Widget _navIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 22,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[400], size: size),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  double _fitTitleFontSize(BuildContext context, String text, double maxWidth) {
    const maxSize = 13.0;
    const minSize = 10.0;
    var low = minSize;
    var high = maxSize;
    var best = minSize;
    while ((high - low) > 0.2) {
      final mid = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: mid,
            fontWeight: FontWeight.w500,
          ),
        ),
        maxLines: 2,
        textDirection: Directionality.of(context),
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      if (painter.didExceedMaxLines) {
        high = mid;
      } else {
        best = mid;
        low = mid;
      }
    }
    return best;
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

  Widget _buildNowIndicator({
    required DateTime now,
    required double hourHeight,
    required double leftOffset,
  }) {
    final minutes = now.hour * 60 + now.minute;
    final topOffset = minutes / 60.0 * hourHeight;
    return Positioned(
      top: topOffset,
      left: leftOffset,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF00E676),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF00E676),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassData classData) {
    final timeRange = '${classData.startTime} - ${classData.endTime}';
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        onTap: classData.link != null && classData.link!.isNotEmpty
            ? () => _openCalendarLink(classData.link!)
            : null,
        borderRadius: BorderRadius.circular(12),
          child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wifi,
                    size: 13,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      classData.room,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (classData.link != null && classData.link!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.link,
                      size: 14,
                      color: const Color(0xFF00E676),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final title = classData.type.isNotEmpty
                                ? '(${classData.type}) ${classData.title}'
                                : classData.title;
                            final fontSize =
                                _fitTitleFontSize(context, title, constraints.maxWidth);
                            return Text(
                              title,
                          style: TextStyle(
                            fontSize: fontSize - 1,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                        if (classData.professor != null &&
                            classData.professor!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            classData.professor!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (classData.badge != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        classData.badge!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: classData.badgeColor ?? Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
}
