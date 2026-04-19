import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/student_performance.dart';

class CoursesTab extends StatefulWidget {
  final List<Course> activeCourses;
  final List<Course> archivedCourses;
  final bool isLoading;
  final void Function(Course) onOpenCourse;
  final void Function(int oldIndex, int newIndex) onReorderActive;
  final void Function(Course) onArchive;
  final void Function(Course) onRestore;
  final List<StudentPerformanceCourse> performanceCourses;
  final bool isLoadingPerformance;
  final void Function(StudentPerformanceCourse) onOpenPerformanceCourse;
  final GradebookResponse? gradebook;
  final bool isLoadingGradebook;

  const CoursesTab({
    super.key,
    required this.activeCourses,
    required this.archivedCourses,
    required this.isLoading,
    required this.onOpenCourse,
    required this.onReorderActive,
    required this.onArchive,
    required this.onRestore,
    required this.performanceCourses,
    required this.isLoadingPerformance,
    required this.onOpenPerformanceCourse,
    required this.gradebook,
    required this.isLoadingGradebook,
  });

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  bool _isEditing = false;
  int _selectedSegment = 0; // 0 = Курсы, 1 = Ведомость, 2 = Зачетка
  final Set<String> _expandedSemesters = {};

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    return Column(
      children: [
        _buildSegmentedControl(isIos),
        Expanded(
          child: _buildSelectedContent(isIos),
        ),
      ],
    );
  }

  Widget _buildSelectedContent(bool isIos) {
    switch (_selectedSegment) {
      case 0:
        return _buildCoursesContent(isIos);
      case 1:
        return _buildGradeSheetContent(isIos);
      case 2:
        return _buildRecordBookContent(isIos);
      default:
        return _buildCoursesContent(isIos);
    }
  }

  Widget _buildSegmentedControl(bool isIos) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: isIos
          ? CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedSegment,
              backgroundColor: c.surface,
              thumbColor: c.accent.withValues(alpha: 0.3),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Курсы', style: TextStyle(fontSize: 13)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Ведомость', style: TextStyle(fontSize: 13)),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Зачетка', style: TextStyle(fontSize: 13)),
                ),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSegment = value);
                }
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildSegmentButton(0, 'Курсы'),
                  _buildSegmentButton(1, 'Ведомость'),
                  _buildSegmentButton(2, 'Зачетка'),
                ],
              ),
            ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final c = AppColors.of(context);
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? c.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? c.accent : c.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesContent(bool isIos) {
    final c = AppColors.of(context);
    if (widget.isLoading) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(
                radius: 14,
                color: c.accent,
              )
            : CircularProgressIndicator(color: c.accent),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          children: [
            Text(
              'Активные курсы',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const Spacer(),
            isIos
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    child: Row(
                      children: [
                        Icon(
                          _isEditing ? CupertinoIcons.check_mark : CupertinoIcons.pencil,
                          size: 16,
                          color: c.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isEditing ? 'Готово' : 'Редактировать',
                          style: TextStyle(color: c.accent, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : TextButton.icon(
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    icon: Icon(
                      _isEditing ? Icons.check : Icons.edit,
                      size: 16,
                      color: c.accent,
                    ),
                    label: Text(
                      _isEditing ? 'Готово' : 'Редактировать',
                      style: TextStyle(color: c.accent, fontSize: 12),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.activeCourses.isEmpty)
          _buildEmptyState(
            icon: Icons.school,
            message: 'Нет активных курсов',
          )
        else if (_isEditing)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: widget.onReorderActive,
            buildDefaultDragHandles: false,
            itemCount: widget.activeCourses.length,
            itemBuilder: (context, index) {
              final course = widget.activeCourses[index];
              return _CourseListTile(
                key: ValueKey('active-${course.id}'),
                course: course,
                onTap: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'В архив',
                      icon: Icon(
                        isIos ? CupertinoIcons.archivebox : Icons.archive,
                        color: c.textTertiary,
                        size: 20,
                      ),
                      onPressed: () => widget.onArchive(course),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        isIos ? CupertinoIcons.line_horizontal_3 : Icons.drag_handle,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else
          ...widget.activeCourses.map(
            (course) => _CourseListTile(
              key: ValueKey('active-${course.id}'),
              course: course,
              onTap: () => widget.onOpenCourse(course),
              trailing: Icon(
                isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                color: c.textTertiary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Архив',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.archivedCourses.length}',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.archivedCourses.isEmpty)
          _buildEmptyState(
            icon: Icons.archive,
            message: 'Архив пуст',
          )
        else
          ...widget.archivedCourses.map(
            (course) => _CourseListTile(
              key: ValueKey('archived-${course.id}'),
              course: course,
              onTap: _isEditing ? null : () => widget.onOpenCourse(course),
              trailing: _isEditing
                  ? (course.isArchived
                      ? const SizedBox(width: 48)
                      : IconButton(
                          tooltip: 'Вернуть',
                          icon: Icon(
                            isIos ? CupertinoIcons.archivebox_fill : Icons.unarchive,
                            color: c.textTertiary,
                            size: 20,
                          ),
                          onPressed: () => widget.onRestore(course),
                        ))
                  : Icon(
                      isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                      color: c.textTertiary,
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildGradeSheetContent(bool isIos) {
    final c = AppColors.of(context);
    if (widget.isLoadingPerformance) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(
                radius: 14,
                color: c.accent,
              )
            : CircularProgressIndicator(color: c.accent),
      );
    }

    final archivedIds = widget.archivedCourses.map((c) => c.id).toSet();
    final visibleCourses = widget.performanceCourses
        .where((course) => !archivedIds.contains(course.id))
        .toList();

    if (visibleCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIos ? CupertinoIcons.doc_chart : Icons.assessment,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет данных об оценках',
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: visibleCourses.length,
      itemBuilder: (context, index) {
        final course = visibleCourses[index];
        return _CourseGradeTile(
          course: course,
          onTap: () => widget.onOpenPerformanceCourse(course),
        );
      },
    );
  }

  Widget _buildSemesterCard(GradebookSemester semester, bool isIos) {
    final c = AppColors.of(context);
    final key = '${semester.year}-${semester.semesterNumber}';
    final isExpanded = _expandedSemesters.contains(key);
    final regularGrades = semester.regularGrades;
    final electiveGrades = semester.electiveGrades;

    if (regularGrades.isEmpty && electiveGrades.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSemesters.remove(key);
                } else {
                  _expandedSemesters.add(key);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isIos ? CupertinoIcons.calendar : Icons.calendar_today,
                      size: 16,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          semester.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${regularGrades.length} предметов',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? (isIos ? CupertinoIcons.chevron_up : Icons.expand_less)
                        : (isIos ? CupertinoIcons.chevron_down : Icons.expand_more),
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(color: c.divider, height: 1),
            ...regularGrades.map((grade) => _buildGradeRow(grade)),
            if (electiveGrades.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Факультативы',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ...electiveGrades.map((grade) => _buildGradeRow(grade)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGradeRow(GradebookGrade grade) {
    final c = AppColors.of(context);
    final gradeColor = _getGradeColor(grade);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.subject,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  grade.assessmentTypeDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              grade.gradeDisplay,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: gradeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(GradebookGrade grade) {
    final c = AppColors.of(context);
    if (grade.grade != null) {
      if (grade.grade! >= 8) return c.accent;
      if (grade.grade! >= 6) return const Color(0xFFFFCA28);
      if (grade.grade! >= 4) return const Color(0xFFFF9800);
      return const Color(0xFFEF5350);
    }
    switch (grade.normalizedGrade) {
      case 'excellent':
        return c.accent;
      case 'good':
        return const Color(0xFFFFCA28);
      case 'satisfactory':
        return const Color(0xFFFF9800);
      case 'passed':
        return c.accent;
      case 'failed':
        return const Color(0xFFEF5350);
      default:
        return c.textTertiary;
    }
  }

  Widget _buildRecordBookContent(bool isIos) {
    final c = AppColors.of(context);
    if (widget.isLoadingGradebook) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(
                radius: 14,
                color: c.accent,
              )
            : CircularProgressIndicator(color: c.accent),
      );
    }

    final gradebook = widget.gradebook;
    if (gradebook == null || gradebook.semesters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIos ? CupertinoIcons.book_solid : Icons.menu_book,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет данных о зачетке',
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        ...gradebook.semesters.map((semester) => _buildSemesterCard(semester, isIos)),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.textTertiary, size: 20),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(color: c.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CourseListTile extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final Widget trailing;

  const _CourseListTile({
    super.key,
    required this.course,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: (isIos
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _buildContent(context, isIos),
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: _buildContent(context, isIos),
            )),
    );
  }

  Widget _buildContent(BuildContext context, bool isIos) {
    final c = AppColors.of(context);
    return Padding(
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
              course.categoryIconAdaptive,
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
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  course.categoryName,
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

}

class _CourseGradeTile extends StatelessWidget {
  final StudentPerformanceCourse course;
  final VoidCallback onTap;

  const _CourseGradeTile({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final gradeColor = _getGradeColor(context, course.total);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isIos
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _buildContent(context, isIos, gradeColor),
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: _buildContent(context, isIos, gradeColor),
            ),
    );
  }

  Widget _buildContent(BuildContext context, bool isIos, Color gradeColor) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                course.total.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
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
                  course.cleanName,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getGradeDescription(course.total),
                  style: TextStyle(
                    fontSize: 12,
                    color: gradeColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
            color: c.textTertiary,
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(BuildContext context, int grade) {
    final c = AppColors.of(context);
    if (grade >= 8) return c.accent;
    if (grade >= 6) return const Color(0xFFFFCA28);
    if (grade >= 4) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  String _getGradeDescription(int grade) {
    if (grade >= 8) return 'Отлично';
    if (grade >= 6) return 'Хорошо';
    if (grade >= 4) return 'Удовлетворительно';
    return 'Неудовлетворительно';
  }
}
