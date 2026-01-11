import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/features/longread/presentation/pages/longread_page.dart';
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : _overview == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Не удалось загрузить курс',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : _buildThemesList(),
    );
  }

  Widget _buildThemesList() {
    final themes = _overview!.themes;
    if (themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, color: Colors.grey[600], size: 48),
            const SizedBox(height: 16),
            Text(
              'Нет доступных тем',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: const Color(0xFF1E1E1E),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: Container(
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
          title: Text(
            theme.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          subtitle: theme.hasExercises
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                )
              : null,
          iconColor: Colors.grey[500],
          collapsedIconColor: Colors.grey[600],
              children: theme.longreads.map((lr) => _buildLongread(theme.name, lr)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLongread(String themeName, Longread longread) {
    return GestureDetector(
      onTap: () => _openLongread(themeName, longread),
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
                  longread.exercises.isEmpty ? Icons.description : Icons.assignment,
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
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey[600],
                ),
              ],
            ),
            if (longread.exercises.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...longread.exercises.map((ex) => _buildExercise(themeName, longread, ex)),
            ],
          ],
        ),
      ),
    );
  }

  void _openLongread(String themeName, Longread longread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LongreadPage(
          longread: longread,
          themeColor: widget.course.categoryColor,
          courseName: widget.course.cleanName,
          themeName: themeName,
        ),
      ),
    );
  }

  Widget _buildExercise(String themeName, Longread longread, ThemeExercise exercise) {
    return InkWell(
      onTap: () => _openExercise(themeName, longread, exercise),
      borderRadius: BorderRadius.circular(6),
      child: Container(
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
            Row(
              children: [
                if (exercise.deadline != null) ...[
                  Icon(
                    Icons.access_time,
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
                  const SizedBox(width: 12),
                ],
                Icon(Icons.star, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'макс. ${exercise.maxScore}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (exercise.activity != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      exercise.activity!.name,
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openExercise(String themeName, Longread longread, ThemeExercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LongreadPage(
          longread: longread,
          themeColor: widget.course.categoryColor,
          courseName: widget.course.cleanName,
          themeName: themeName,
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
