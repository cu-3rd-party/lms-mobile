import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/core/services/analytics_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_extras.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/data/models/exam_item.dart';
import 'package:cumobile/data/services/exams_service.dart';
import 'package:cumobile/features/course/widgets/course_recordings_tab.dart';
import 'package:cumobile/features/longread/pages/longread_page.dart';
import 'package:cumobile/data/services/api_service.dart';

class CoursePage extends StatefulWidget {
  final Course course;

  const CoursePage({super.key, required this.course});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  CourseOverview? _overview;
  bool _isLoading = true;
  List<ExamItem> _exams = [];
  static final Logger _log = Logger('CoursePage');
  final Set<int> _expandedThemes = {};
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _section = 0;
  CourseProgress? _progress;
  StudentTask? _nearestDeadline;

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _loadExams();
    _loadProgress();
    _loadNearestDeadline();
  }

  Future<void> _loadProgress() async {
    final progress = await apiService.fetchCourseProgress(widget.course.id);
    if (!mounted || progress == null) return;
    setState(() => _progress = progress);
  }

  Future<void> _loadNearestDeadline() async {
    final deadlines = await apiService.fetchDeadlines(limit: 1, courseId: widget.course.id);
    if (!mounted || deadlines == null || deadlines.isEmpty) return;
    setState(() => _nearestDeadline = deadlines.first);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    final exams = await examsService.fetchForCourse(widget.course.cleanName);
    if (!mounted || exams.isEmpty) return;
    setState(() => _exams = exams);
  }

  Future<void> _loadOverview() async {
    try {
      final overview = await apiService.fetchCourseOverview(widget.course.id);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e, st) {
      _log.warning('Error loading course overview', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final courseBody = _isLoading
        ? Center(
            child: isIos
                ? CupertinoActivityIndicator(
                    radius: 14,
                    color: c.accent,
                  )
                : CircularProgressIndicator(color: c.accent),
          )
        : _overview == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIos ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
                      color: c.textTertiary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить курс',
                      style: TextStyle(color: c.textTertiary),
                    ),
                  ],
                ),
              )
            : _buildThemesList();
    final body = Column(
      children: [
        if (!_isSearching) _buildSectionSwitch(isIos),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              courseBody,
              CourseRecordingsTab(
                courseId: widget.course.id,
                themeColor: widget.course.categoryColor,
              ),
            ],
          ),
        ),
      ],
    );
    final canSearch = _section == 0;

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: _isSearching
              ? CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Поиск...',
                  placeholderStyle: TextStyle(
                    color: c.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  autofocus: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && _searchQuery.isEmpty) {
                      Analytics.courseSearchUsed(courseId: widget.course.id);
                    }
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                )
              : Text(
                  widget.course.cleanName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _closeSearch,
                  child: const Text('Отмена', style: TextStyle(fontSize: 14)),
                )
              else if (canSearch)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _isSearching = true),
                  child: const Icon(CupertinoIcons.search, size: 22),
                ),
            ],
          ),
        ),
        backgroundColor: c.background,
        child: SafeArea(bottom: false, child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.arrow_back, color: c.textPrimary),
          onPressed: _isSearching ? _closeSearch : () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Поиск...',
                  hintStyle: TextStyle(
                    color: c.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && _searchQuery.isEmpty) {
                    Analytics.courseSearchUsed(courseId: widget.course.id);
                  }
                  setState(() => _searchQuery = value.toLowerCase());
                },
              )
            : Text(
                widget.course.cleanName,
                style: TextStyle(color: c.textPrimary, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_isSearching && canSearch)
            IconButton(
              icon: Icon(Icons.search, color: c.textPrimary),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSectionSwitch(bool isIos) {
    final c = AppColors.of(context);
    const labels = {0: 'Курс', 1: 'Видеозаписи'};
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: isIos
            ? CupertinoSlidingSegmentedControl<int>(
                groupValue: _section,
                backgroundColor: c.surface,
                thumbColor: c.accent.withValues(alpha: 0.3),
                children: labels.map(
                  (key, label) => MapEntry(
                    key,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(label, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
                onValueChanged: (value) {
                  if (value != null) setState(() => _section = value);
                },
              )
            : SegmentedButton<int>(
                segments: labels.entries
                    .map((e) => ButtonSegment<int>(value: e.key, label: Text(e.value)))
                    .toList(),
                selected: {_section},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _section = value.first),
              ),
      ),
    );
  }

  List<Widget> _buildHeaderCards(bool isIos) {
    final overview = _overview;
    final syllabusUrl = overview?.syllabusUrl;
    final chatUrl = overview?.timeChannelUrl;
    final links = <Widget>[
      if (syllabusUrl != null)
        _buildLinkCard(
          caption: 'О курсе',
          title: 'Силлабус',
          icon: isIos ? CupertinoIcons.book_fill : Icons.menu_book,
          url: syllabusUrl,
        ),
      if (chatUrl != null)
        _buildLinkCard(
          caption: 'Time',
          title: 'Чат курса',
          icon: isIos ? CupertinoIcons.chat_bubble_2_fill : Icons.forum,
          url: chatUrl,
        ),
    ];
    final progress = _progress;
    final deadline = _nearestDeadline;

    final cards = <Widget>[];
    if (progress != null || links.isNotEmpty) {
      cards.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress != null) Expanded(flex: 3, child: _buildProgressCard(progress)),
              if (progress != null && links.isNotEmpty) const SizedBox(width: 10),
              if (links.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      for (var i = 0; i < links.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Expanded(child: links[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }
    if (deadline != null) {
      cards.add(_buildDeadlineCard(deadline, isIos));
      cards.add(const SizedBox(height: 12));
    }
    if (cards.isNotEmpty) cards.add(const SizedBox(height: 4));
    return cards;
  }

  BoxDecoration _cardDecoration() {
    final c = AppColors.of(context);
    return BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
    );
  }

  Widget _buildProgressCard(CourseProgress progress) {
    final c = AppColors.of(context);
    const earnedColor = Color(0xFF4CAF50);
    const leftColor = Color(0xFFFFCA28);
    final max = progress.maxScore <= 0 ? 1.0 : progress.maxScore;
    final earned = (progress.earnedScore / max).clamp(0.0, 1.0);
    final left = (progress.leftToEarnScore / max).clamp(0.0, 1.0 - earned);

    Widget legend(Color color, String label, double value) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ),
            Text(
              CourseProgress.format(value),
              style: TextStyle(fontSize: 12, color: c.textPrimary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Прогресс по курсу',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CourseProgress.format(progress.earnedScore),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'из ${CourseProgress.format(progress.maxScore)}',
                style: TextStyle(fontSize: 13, color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    children: [
                      Container(color: c.surfaceVariant),
                      Positioned(
                        left: width * earned,
                        width: width * left,
                        top: 0,
                        bottom: 0,
                        child: Container(color: leftColor),
                      ),
                      Positioned(
                        left: 0,
                        width: width * earned,
                        top: 0,
                        bottom: 0,
                        child: Container(color: earnedColor),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          legend(earnedColor, 'Накоплено', progress.earnedScore),
          legend(leftColor, 'Можно набрать', progress.leftToEarnScore),
        ],
      ),
    );
  }

  Widget _buildLinkCard({
    required String caption,
    required String title,
    required IconData icon,
    required String url,
  }) {
    final c = AppColors.of(context);
    final color = widget.course.categoryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(caption, style: TextStyle(fontSize: 11, color: c.textTertiary)),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineCard(StudentTask task, bool isIos) {
    final c = AppColors.of(context);
    const accent = Color(0xFFFFCA28);
    final deadline = task.deadline?.toLocal();
    final dateText = deadline == null
        ? ''
        : DateFormat('EE, d MMMM, HH:mm', 'ru_RU').format(deadline);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDeadlineTask(task),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ближайший дедлайн',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (deadline != null)
                  Text(
                    _timeLeftLabel(deadline),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      margin: const EdgeInsets.only(left: 10, right: 10),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.exercise.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: c.textPrimary),
                          ),
                          if (dateText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              dateText,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFE0A800)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                      size: 16,
                      color: c.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLeftLabel(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'Просрочено';
    if (diff.inDays >= 1) {
      final days = diff.inDays;
      return 'Осталось $days ${_pluralize(days, 'день', 'дня', 'дней')}';
    }
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      return 'Осталось $hours ${_pluralize(hours, 'час', 'часа', 'часов')}';
    }
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return 'Осталось $minutes ${_pluralize(minutes, 'минута', 'минуты', 'минут')}';
  }

  void _openDeadlineTask(StudentTask task) {
    final overview = _overview;
    if (overview == null) return;
    for (final theme in overview.themes) {
      for (final longread in theme.longreads) {
        for (final exercise in longread.exercises) {
          if (exercise.id == task.exercise.id) {
            _openExercise(theme, longread, exercise);
            return;
          }
        }
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildThemesList() {
    final c = AppColors.of(context);
    final themes = _overview!.themes;
    if (themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.folder : Icons.folder_open,
              color: c.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет доступных тем',
              style: TextStyle(color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filteredThemes = query.isEmpty
        ? themes
        : themes
            .map((theme) {
              if (theme.name.toLowerCase().contains(query)) {
                return theme;
              }
              final matchingLongreads = theme.longreads
                  .where((lr) =>
                      lr.name.toLowerCase().contains(query) ||
                      lr.exercises.any((ex) =>
                          ex.name.toLowerCase().contains(query) ||
                          (ex.activity?.name.toLowerCase().contains(query) ?? false)))
                  .toList();
              if (matchingLongreads.isEmpty) {
                return null;
              }
              return CourseTheme(
                id: theme.id,
                name: theme.name,
                order: theme.order,
                state: theme.state,
                longreads: matchingLongreads,
              );
            })
            .whereType<CourseTheme>()
            .toList();

    if (filteredThemes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.search : Icons.search,
              color: c.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final listPadding = EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset);

    final rows = _buildCourseRows(filteredThemes, query.isEmpty);
    final isIos = Platform.isIOS;
    final header = query.isEmpty ? _buildHeaderCards(isIos) : const <Widget>[];

    return ListView.builder(
      padding: listPadding,
      itemCount: header.length + rows.length,
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        final row = rows[index - header.length];
        final exam = row.exam;
        if (exam != null) return _buildExamCard(exam);
        return isIos
            ? _buildThemeCardCupertino(row.theme!, row.number!)
            : _buildThemeCard(row.theme!, row.number!);
      },
    );
  }

  static final RegExp _weekPattern =
      RegExp(r'недел[яиюе]\w*\s*[№#]?\s*(\d+)', caseSensitive: false, unicode: true);

  static int? _themeWeek(String name) {
    final match = _weekPattern.firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  List<_CourseRow> _buildCourseRows(List<CourseTheme> themes, bool withExams) {
    final rows = <_CourseRow>[];

    if (!withExams || _exams.isEmpty) {
      for (var i = 0; i < themes.length; i++) {
        rows.add(_CourseRow.theme(themes[i], i + 1));
      }
      return rows;
    }

    final themeWeeks = themes.map((theme) => _themeWeek(theme.name)).toList();
    final knownWeeks = themeWeeks.whereType<int>();
    final maxWeek = knownWeeks.isEmpty ? null : knownWeeks.reduce((a, b) => a > b ? a : b);
    final sortedExams = [..._exams]
      ..sort((a, b) => (a.weekNumber ?? 1 << 30).compareTo(b.weekNumber ?? 1 << 30));

    final beforeThemes = <ExamItem>[];
    final afterTheme = <int, List<ExamItem>>{};
    final atEnd = <ExamItem>[];

    for (final exam in sortedExams) {
      final week = exam.weekNumber;
      if (week == null || maxWeek == null || week > maxWeek) {
        atEnd.add(exam);
        continue;
      }
      int? anchor;
      for (var i = 0; i < themes.length; i++) {
        final themeWeek = themeWeeks[i];
        if (themeWeek != null && themeWeek <= week) anchor = i;
      }
      if (anchor == null) {
        beforeThemes.add(exam);
      } else {
        afterTheme.putIfAbsent(anchor, () => []).add(exam);
      }
    }

    final firstWeekTheme = themeWeeks.indexWhere((week) => week != null);
    for (var i = 0; i < themes.length; i++) {
      if (i == firstWeekTheme) {
        rows.addAll(beforeThemes.map(_CourseRow.exam));
      }
      rows.add(_CourseRow.theme(themes[i], i + 1));
      rows.addAll((afterTheme[i] ?? const []).map(_CourseRow.exam));
    }
    rows.addAll(atEnd.map(_CourseRow.exam));

    return rows;
  }

  static IconData _examIcon(String name, bool isIos) {
    final lower = name.toLowerCase();
    if (lower.contains('контест')) {
      return isIos ? CupertinoIcons.chevron_left_slash_chevron_right : Icons.code;
    }
    if (lower.contains('защит') || lower.contains('проект')) {
      return isIos ? CupertinoIcons.person_2_fill : Icons.co_present;
    }
    if (lower.contains('экзамен') || lower.contains('зачет') || lower.contains('зачёт')) {
      return isIos ? CupertinoIcons.book_fill : Icons.school;
    }
    if (lower.contains('коллоквиум')) {
      return isIos ? CupertinoIcons.chat_bubble_2_fill : Icons.forum;
    }
    if (lower.contains('тест')) {
      return isIos ? CupertinoIcons.list_bullet : Icons.quiz;
    }
    if (lower.contains('контрольн')) {
      return isIos ? CupertinoIcons.pencil : Icons.edit_note;
    }
    return isIos ? CupertinoIcons.checkmark_seal_fill : Icons.fact_check;
  }

  Widget _buildExamCard(ExamItem exam) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final accent = c.danger;
    final week = exam.weekNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  _examIcon(exam.name, isIos),
                  size: 16,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                  if (week != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Неделя $week',
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _buildThemeCard(CourseTheme theme, int number) {
    final c = AppColors.of(context);
    final isExpanded = _expandedThemes.contains(theme.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleTheme(theme.id),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.course.categoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.course.categoryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            theme.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary,
                            ),
                          ),
                          if (theme.hasExercises)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                                style: TextStyle(fontSize: 12, color: c.textTertiary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: c.textTertiary,
                      size: 24,
                    ),
                  ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Column(
                        children: theme.longreads
                            .map((lr) => _buildLongread(theme, lr))
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCardCupertino(CourseTheme theme, int number) {
    final c = AppColors.of(context);
    final isExpanded = _expandedThemes.contains(theme.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleTheme(theme.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.course.categoryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.course.categoryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                        if (theme.hasExercises)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                              style: TextStyle(fontSize: 12, color: c.textTertiary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: Column(
                      children: theme.longreads
                          .map((lr) => _buildLongread(theme, lr))
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLongread(CourseTheme theme, Longread longread) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    return GestureDetector(
      onTap: () => _openLongread(theme, longread),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  longread.exercises.isEmpty
                      ? (isIos ? CupertinoIcons.doc_plaintext : Icons.description)
                      : (isIos ? CupertinoIcons.square_list : Icons.assignment),
                  size: 16,
                  color: widget.course.categoryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    longread.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
            if (longread.exercises.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...longread.exercises.map((ex) => _buildExercise(theme, longread, ex)),
            ],
          ],
        ),
      ),
    );
  }

  void _openLongread(CourseTheme theme, Longread longread) {
    Analytics.courseLongreadCellPressed(
      courseId: widget.course.id,
      themeId: theme.id,
      longreadId: longread.id,
    );
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
              ),
            )
          : MaterialPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
              ),
            ),
    );
  }

  Widget _buildExercise(CourseTheme theme, Longread longread, ThemeExercise exercise) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final content = Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: TextStyle(fontSize: 12, color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          if (exercise.deadline != null)
            Row(
              children: [
                Icon(
                  isIos ? CupertinoIcons.time : Icons.access_time,
                  size: 12,
                  color: exercise.isOverdue ? c.danger : c.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  exercise.formattedDeadline,
                  style: TextStyle(
                    fontSize: 11,
                    color: exercise.isOverdue ? c.danger : c.textTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return isIos
        ? GestureDetector(
            onTap: () => _openExercise(theme, longread, exercise),
            child: content,
          )
        : InkWell(
            onTap: () => _openExercise(theme, longread, exercise),
            borderRadius: BorderRadius.circular(6),
            child: content,
          );
  }

  void _toggleTheme(int themeId) {
    setState(() {
      if (_expandedThemes.contains(themeId)) {
        _expandedThemes.remove(themeId);
      } else {
        _expandedThemes.add(themeId);
        Analytics.courseThemeCellPressed(
          courseId: widget.course.id,
          themeId: themeId,
        );
      }
    });
  }

  void _openExercise(CourseTheme theme, Longread longread, ThemeExercise exercise) {
    Analytics.courseExerciseCellPressed(
      courseId: widget.course.id,
      themeId: theme.id,
    );
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
                selectedExerciseName: exercise.name,
              ),
            )
          : MaterialPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
                selectedExerciseName: exercise.name,
              ),
            ),
    );
  }

  String _pluralize(int count, String one, String few, String many) {
    if (count % 10 == 1 && count % 100 != 11) return one;
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return few;
    return many;
  }
}


class _CourseRow {
  final CourseTheme? theme;
  final int? number;
  final ExamItem? exam;

  const _CourseRow.theme(this.theme, this.number) : exam = null;

  const _CourseRow.exam(this.exam)
      : theme = null,
        number = null;
}
