import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/core/services/analytics_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/core/ui/sync_indicator.dart';
import 'package:cumobile/data/models/student_performance.dart';
import 'package:cumobile/data/services/api_service.dart';

class CoursePerformancePage extends StatefulWidget {
  final StudentPerformanceCourse course;

  const CoursePerformancePage({
    super.key,
    required this.course,
  });

  @override
  State<CoursePerformancePage> createState() => _CoursePerformancePageState();
}

class _CoursePerformancePageState extends State<CoursePerformancePage> with SyncTracker {
  static final Logger _log = Logger('CoursePerformancePage');
  bool _isLoading = true;
  CourseExercisesResponse? _exercisesResponse;
  CourseStudentPerformanceResponse? _performanceResponse;
  List<ActivityPerformance>? _activitiesPerformance;
  int _selectedTab = 0;
  String _selectedActivityFilter = 'all';

  @override
  void initState() {
    super.initState();
    trackSync(_loadData());
  }

  void _applyCached(void Function() update) {
    if (!mounted) return;
    setState(() {
      update();
      if (_exercisesResponse != null && _performanceResponse != null) _isLoading = false;
    });
  }

  Future<void> _loadData() async {
    try {
      final courseId = widget.course.id;
      final results = await Future.wait([
        apiService.fetchCourseExercises(
          courseId,
          onCached: (cached) => _applyCached(() => _exercisesResponse = cached),
        ),
        apiService.fetchCourseStudentPerformance(
          courseId,
          onCached: (cached) => _applyCached(() => _performanceResponse = cached),
        ),
        apiService.fetchActivitiesPerformance(
          courseId,
          onCached: (cached) => _applyCached(() => _activitiesPerformance = cached),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _exercisesResponse = results[0] as CourseExercisesResponse? ?? _exercisesResponse;
        _performanceResponse =
            results[1] as CourseStudentPerformanceResponse? ?? _performanceResponse;
        _activitiesPerformance =
            results[2] as List<ActivityPerformance>? ?? _activitiesPerformance;
        _isLoading = false;
      });
    } catch (e, st) {
      _log.warning('Error loading course performance', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<ExerciseWithScore> _getExercisesWithScores() {
    if (_exercisesResponse == null || _performanceResponse == null) return [];

    final scoreMap = <int, TaskScore>{};
    for (final task in _performanceResponse!.tasks) {
      scoreMap[task.exerciseId] = task;
    }

    return _exercisesResponse!.exercises.map((exercise) {
      return ExerciseWithScore(
        exercise: exercise,
        score: scoreMap[exercise.id],
      );
    }).toList();
  }

  List<String> _getAvailableActivities() {
    final activities = <String>{'all'};
    for (final exercise in _exercisesResponse?.exercises ?? []) {
      if (exercise.activity != null) {
        activities.add(exercise.activity!.name);
      }
    }
    return activities.toList();
  }

  List<ExerciseWithScore> _getFilteredExercises() {
    final exercises = _getExercisesWithScores();
    if (_selectedActivityFilter == 'all') return exercises;
    return exercises
        .where((e) => e.activityName == _selectedActivityFilter)
        .toList();
  }

  List<ActivitySummary> _getActivitySummaries() {
    final tasks = _performanceResponse?.tasks ?? const <TaskScore>[];
    final exercises = _exercisesResponse?.exercises ?? const <CourseExercise>[];
    final serverActivities = _activitiesPerformance;
    if (serverActivities != null && serverActivities.isNotEmpty) {
      return serverActivities.map((item) {
        final id = item.activity.id;
        final activityTasks = tasks.where((t) => t.activity.id == id);
        return ActivitySummary(
          activityId: id,
          activityName: item.activity.name,
          completedCount: activityTasks.where((t) => t.state == 'evaluated').length,
          gradedCount: activityTasks
              .where((t) => t.state == 'evaluated' || t.state == 'failed')
              .length,
          maxCount: item.activity.maxExercisesCount ?? activityTasks.length,
          scoreSum: activityTasks.fold(0.0, (sum, t) => sum + t.score),
          weight: item.activity.weight,
          serverAverage: item.average,
          serverTotal: item.total,
        );
      }).toList();
    }

    final order = <int>[];
    final names = <int, String>{};
    final weights = <int, double>{};
    final maxCounts = <int, int>{};
    final exerciseCounts = <int, int>{};
    final scoreSums = <int, double>{};
    final completed = <int, int>{};
    final graded = <int, int>{};

    for (final task in tasks) {
      final id = task.activity.id;
      if (!names.containsKey(id)) order.add(id);
      names[id] = task.activity.name;
      weights[id] = task.activity.weight;
      final max = task.activity.maxExercisesCount;
      if (max != null) maxCounts[id] = max;
      scoreSums[id] = (scoreSums[id] ?? 0) + task.score + (task.extraScore ?? 0);
      if (task.state == 'evaluated') completed[id] = (completed[id] ?? 0) + 1;
      if (task.state == 'evaluated' || task.state == 'failed') {
        graded[id] = (graded[id] ?? 0) + 1;
      }
    }

    for (final exercise in exercises) {
      final activity = exercise.activity;
      if (activity == null) continue;
      final id = activity.id;
      exerciseCounts[id] = (exerciseCounts[id] ?? 0) + 1;
      if (names.containsKey(id)) continue;
      final weight = activity.weight;
      if (weight == null) continue;
      order.add(id);
      names[id] = activity.name;
      weights[id] = weight;
      final max = activity.maxExercisesCount;
      if (max != null) maxCounts[id] = max;
    }

    return order.map((id) {
      final taskCount = tasks.where((t) => t.activity.id == id).length;
      final fallbackMax = exerciseCounts[id] ?? taskCount;
      return ActivitySummary(
        activityId: id,
        activityName: names[id] ?? '',
        completedCount: completed[id] ?? 0,
        gradedCount: graded[id] ?? 0,
        maxCount: maxCounts[id] ?? (fallbackMax > 0 ? fallbackMax : taskCount),
        scoreSum: scoreSums[id] ?? 0,
        weight: weights[id] ?? 0,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;

    if (isIos) {
      return CupertinoPageScaffold(
        backgroundColor: c.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: c.background,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(CupertinoIcons.back, color: c.accent),
          ),
          middle: Text(
            widget.course.cleanName,
            style: TextStyle(color: c.textPrimary, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: SyncIndicator(visible: isSyncing && !_isLoading),
        ),
        child: SafeArea(bottom: false, child: _buildBody(isIos)),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.cleanName,
          style: TextStyle(color: c.textPrimary, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Center(child: SyncIndicator(visible: isSyncing && !_isLoading, size: 16)),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody(isIos),
    );
  }

  Widget _buildBody(bool isIos) {
    final c = AppColors.of(context);
    if (_isLoading) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(
                radius: 14,
                color: c.accent,
              )
            : CircularProgressIndicator(color: c.accent),
      );
    }

    return Column(
      children: [
        _buildTotalGradeCard(),
        _buildTabSelector(isIos),
        Expanded(
          child: _selectedTab == 0
              ? _buildScoresTab(isIos)
              : _buildPerformanceTab(isIos),
        ),
      ],
    );
  }

  Widget _buildTotalGradeCard() {
    final c = AppColors.of(context);
    final gradeColor = _getGradeColor(widget.course.total);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.course.total.toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итоговая оценка',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGradeDescription(widget.course.total),
                  style: TextStyle(
                    fontSize: 14,
                    color: gradeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(bool isIos) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Analytics.performanceTabPressed(
                  tab: 'scores',
                  courseId: widget.course.id,
                );
                setState(() => _selectedTab = 0);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? c.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Набранные баллы',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedTab == 0 ? c.accent : c.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Analytics.performanceTabPressed(
                  tab: 'performance',
                  courseId: widget.course.id,
                );
                setState(() => _selectedTab = 1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? c.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Успеваемость',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedTab == 1 ? c.accent : c.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoresTab(bool isIos) {
    final c = AppColors.of(context);
    final activities = _getAvailableActivities();
    final exercises = _getFilteredExercises();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        _buildActivityFilter(activities, isIos),
        Expanded(
          child: exercises.isEmpty
              ? Center(
                  child: Text(
                    'Нет заданий',
                    style: TextStyle(color: c.textTertiary),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final item = exercises[index];
                    return _buildExerciseTile(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivityFilter(List<String> activities, bool isIos) {
    final c = AppColors.of(context);
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          final isSelected = activity == _selectedActivityFilter;
          final displayName = activity == 'all' ? 'Все активности' : activity;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                Analytics.performanceActivityFilterChanged(
                  courseId: widget.course.id,
                  activityType: activity,
                );
                setState(() => _selectedActivityFilter = activity);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? c.accent.withValues(alpha: 0.2)
                      : c.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? c.accent : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? c.accent : c.textTertiary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseTile(ExerciseWithScore item) {
    final c = AppColors.of(context);
    final scoreColor = _getScoreColor(item.scoreValue, item.maxScore);
    final hasScore = item.score != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.themeName,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasScore
                      ? '${_formatScore(item.scoreValue)} / ${item.maxScore}'
                      : '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.exercise.name,
            style: TextStyle(
              fontSize: 14,
              color: c.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.activityName,
            style: TextStyle(
              fontSize: 12,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(bool isIos) {
    final c = AppColors.of(context);
    final summaries = _getActivitySummaries();
    final accumulated =
        summaries.fold<double>(0, (sum, s) => sum + s.totalContribution);
    final achievable =
        summaries.fold<double>(0, (sum, s) => sum + s.achievableContribution);
    final accumulatedText = _formatDecimal(accumulated, 2);
    final achievableText = _formatDecimal(achievable, 2);
    final roundedAchievable = double.parse(achievable.toStringAsFixed(2));
    final percent = roundedAchievable > 0
        ? (double.parse(accumulated.toStringAsFixed(2)) / roundedAchievable * 100).round()
        : null;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildHeaderCell('Активность', flex: 3),
                  _buildHeaderCell('Выполн.', flex: 1),
                  _buildHeaderCell('Ср. балл', flex: 1),
                  const SizedBox(width: 8),
                  Text('x', style: TextStyle(color: c.textTertiary, fontSize: 12)),
                  const SizedBox(width: 8),
                  _buildHeaderCell('Вес', flex: 1),
                  const SizedBox(width: 8),
                  Text('=', style: TextStyle(color: c.textTertiary, fontSize: 12)),
                  const SizedBox(width: 8),
                  _buildHeaderCell('Итого', flex: 1),
                ],
              ),
              Divider(color: c.divider, height: 16),
              ...summaries.map((summary) => _buildSummaryRow(summary)),
              if (summaries.isNotEmpty) ...[
                Divider(color: c.divider, height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Итог за курс',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      widget.course.total.toString(),
                      style: TextStyle(
                        color: _getGradeColor(widget.course.total),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                      children: [
                        const TextSpan(text: 'Накоплено на данный момент: '),
                        TextSpan(
                          text: '$accumulatedText / $achievableText',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (percent != null) TextSpan(text: ' ($percent%)'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    final c = AppColors.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(ActivitySummary summary) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              summary.activityName,
              style: TextStyle(color: c.textPrimary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${summary.completedCount}/${summary.maxCount}',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textPrimary, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _formatDecimal(summary.averageScore, 2),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getScoreColor(summary.averageRatio * 10, 10),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('x', style: TextStyle(color: c.textTertiary, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              '${_formatDecimal(summary.weight * 100, 0)}%',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text('=', style: TextStyle(color: c.textTertiary, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              _formatDecimal(summary.displayTotal, 2),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getScoreColor(summary.averageRatio * 10, 10),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(int grade) {
    final c = AppColors.of(context);
    if (grade >= 8) return c.accent;
    if (grade >= 6) return const Color(0xFFFFCA28);
    if (grade >= 4) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  Color _getScoreColor(double score, int maxScore) {
    final c = AppColors.of(context);
    final percentage = maxScore > 0 ? (score / maxScore) : 0.0;
    if (percentage >= 0.8) return c.accent;
    if (percentage >= 0.6) return const Color(0xFFFFCA28);
    if (percentage >= 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  String _formatScore(double value) {
    return _formatDecimal(value, 1);
  }

  String _formatDecimal(num value, int fractionDigits) {
    final fixed = value.toStringAsFixed(fractionDigits);
    if (!fixed.contains('.')) return fixed;
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _getGradeDescription(int grade) {
    if (grade >= 8) return 'Отлично';
    if (grade >= 6) return 'Хорошо';
    if (grade >= 4) return 'Удовлетворительно';
    return 'Неудовлетворительно';
  }
}
