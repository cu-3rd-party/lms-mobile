import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

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

class _CoursePerformancePageState extends State<CoursePerformancePage> {
  static final Logger _log = Logger('CoursePerformancePage');
  bool _isLoading = true;
  CourseExercisesResponse? _exercisesResponse;
  CourseStudentPerformanceResponse? _performanceResponse;
  int _selectedTab = 0;
  String _selectedActivityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        apiService.fetchCourseExercises(widget.course.id),
        apiService.fetchCourseStudentPerformance(widget.course.id),
      ]);
      if (!mounted) return;
      setState(() {
        _exercisesResponse = results[0] as CourseExercisesResponse?;
        _performanceResponse = results[1] as CourseStudentPerformanceResponse?;
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
    if (_performanceResponse == null) return [];

    final activityMap = <int, List<TaskScore>>{};
    for (final task in _performanceResponse!.tasks) {
      activityMap.putIfAbsent(task.activity.id, () => []).add(task);
    }

    final summaries = <ActivitySummary>[];
    for (final entry in activityMap.entries) {
      final tasks = entry.value;
      if (tasks.isEmpty) continue;

      final activityName = tasks.first.activity.name;
      final weight = tasks.first.activity.weight;
      final totalScore = tasks.fold<double>(0, (sum, t) => sum + t.score);
      final avgScore = totalScore / tasks.length;

      summaries.add(ActivitySummary(
        activityId: entry.key,
        activityName: activityName,
        count: tasks.length,
        averageScore: avgScore,
        weight: weight,
      ));
    }

    summaries.sort((a, b) => b.weight.compareTo(a.weight));
    return summaries;
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    if (isIos) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFF121212),
        navigationBar: CupertinoNavigationBar(
          backgroundColor: const Color(0xFF121212),
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.back, color: Color(0xFF00E676)),
          ),
          middle: Text(
            widget.course.cleanName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        child: SafeArea(child: _buildBody(isIos)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00E676)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.cleanName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(isIos),
    );
  }

  Widget _buildBody(bool isIos) {
    if (_isLoading) {
      return Center(
        child: isIos
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
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
    final gradeColor = _getGradeColor(widget.course.total);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
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
                const Text(
                  'Итоговая оценка',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? const Color(0xFF00E676).withValues(alpha: 0.2)
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
                    color: _selectedTab == 0
                        ? const Color(0xFF00E676)
                        : Colors.grey[500],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? const Color(0xFF00E676).withValues(alpha: 0.2)
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
                    color: _selectedTab == 1
                        ? const Color(0xFF00E676)
                        : Colors.grey[500],
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
    final activities = _getAvailableActivities();
    final exercises = _getFilteredExercises();

    return Column(
      children: [
        _buildActivityFilter(activities, isIos),
        Expanded(
          child: exercises.isEmpty
              ? Center(
                  child: Text(
                    'Нет заданий',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              onTap: () => setState(() => _selectedActivityFilter = activity),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00E676).withValues(alpha: 0.2)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E676)
                        : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? const Color(0xFF00E676) : Colors.grey[400],
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
    final scoreColor = _getScoreColor(item.scoreValue, item.maxScore);
    final hasScore = item.score != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
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
                    color: Colors.grey[500],
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
                      ? '${item.scoreValue.toStringAsFixed(1)} / ${item.maxScore}'
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.activityName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(bool isIos) {
    final summaries = _getActivitySummaries();
    final totalContribution =
        summaries.fold<double>(0, (sum, s) => sum + s.totalContribution);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildHeaderCell('Активность', flex: 3),
                  _buildHeaderCell('Кол-во', flex: 1),
                  _buildHeaderCell('Ср. балл', flex: 1),
                  const SizedBox(width: 8),
                  const Text('x', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  _buildHeaderCell('Вес', flex: 1),
                  const SizedBox(width: 8),
                  const Text('=', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  _buildHeaderCell('Итого', flex: 1),
                ],
              ),
              const Divider(color: Color(0xFF2E2E2E), height: 16),
              ...summaries.map((summary) => _buildSummaryRow(summary)),
              if (summaries.isNotEmpty) ...[
                const Divider(color: Color(0xFF2E2E2E), height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Итого',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Expanded(flex: 1, child: SizedBox()),
                    const Expanded(flex: 1, child: SizedBox()),
                    const SizedBox(width: 8),
                    const Text('', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    const Expanded(flex: 1, child: SizedBox()),
                    const SizedBox(width: 8),
                    const Text('', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(
                        totalContribution.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _getGradeColor(totalContribution.round()),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(ActivitySummary summary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              summary.activityName,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              summary.count.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              summary.averageScore.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getScoreColor(summary.averageScore, 10),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('x', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              summary.weight.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          const Text('=', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              summary.totalContribution.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getGradeColor((summary.totalContribution * 10).round()),
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
    if (grade >= 8) return const Color(0xFF00E676);
    if (grade >= 6) return const Color(0xFFFFCA28);
    if (grade >= 4) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  Color _getScoreColor(double score, int maxScore) {
    final percentage = maxScore > 0 ? (score / maxScore) : 0.0;
    if (percentage >= 0.8) return const Color(0xFF00E676);
    if (percentage >= 0.6) return const Color(0xFFFFCA28);
    if (percentage >= 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  String _getGradeDescription(int grade) {
    if (grade >= 8) return 'Отлично';
    if (grade >= 6) return 'Хорошо';
    if (grade >= 4) return 'Удовлетворительно';
    return 'Неудовлетворительно';
  }
}
