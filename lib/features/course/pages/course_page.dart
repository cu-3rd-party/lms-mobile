import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_overview.dart';
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
  static final Logger _log = Logger('CoursePage');
  final Set<int> _expandedThemes = {};

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    try {
      final overview = await apiService.fetchCourseOverview(widget.course.id);
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e, st) {
      _log.warning('Error loading course overview', e, st);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final body = _isLoading
        ? Center(
            child: isIos
                ? const CupertinoActivityIndicator(
                    radius: 14,
                    color: Color(0xFF00E676),
                  )
                : const CircularProgressIndicator(color: Color(0xFF00E676)),
          )
        : _overview == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIos ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
                      color: Colors.grey[600],
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить курс',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            : _buildThemesList();

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.course.cleanName),
        ),
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(top: false, child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.cleanName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }

  Widget _buildThemesList() {
    final themes = _overview!.themes;
    if (themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.folder : Icons.folder_open,
              color: Colors.grey[600],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет доступных тем',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (Platform.isIOS) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: themes.length,
        itemBuilder: (context, index) {
          final theme = themes[index];
          return _buildThemeCardCupertino(theme, index + 1);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final theme = themes[index];
        return _buildThemeCard(theme, index + 1);
      },
    );
  }

  Widget _buildThemeCard(CourseTheme theme, int number) {
    final isExpanded = _expandedThemes.contains(theme.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1E1E1E),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          if (theme.hasExercises)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[500],
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
    final isExpanded = _expandedThemes.contains(theme.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        if (theme.hasExercises)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    color: Colors.grey[500],
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
    final isIos = Platform.isIOS;
    return GestureDetector(
      onTap: () => _openLongread(theme, longread),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                  size: 18,
                  color: Colors.grey[600],
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
    final isIos = Platform.isIOS;
    final content = Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: exercise.isOverdue
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 6),
          if (exercise.deadline != null)
            Row(
              children: [
                Icon(
                  isIos ? CupertinoIcons.time : Icons.access_time,
                  size: 12,
                  color: exercise.isOverdue ? Colors.redAccent : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  exercise.formattedDeadline,
                  style: TextStyle(
                    fontSize: 11,
                    color: exercise.isOverdue ? Colors.redAccent : Colors.grey[500],
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
      }
    });
  }

  void _openExercise(CourseTheme theme, Longread longread, ThemeExercise exercise) {
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
