import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  });

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  bool _isEditing = false;
  int _selectedSegment = 0; // 0 = Курсы, 1 = Ведомость

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    return Column(
      children: [
        _buildSegmentedControl(isIos),
        Expanded(
          child: _selectedSegment == 0
              ? _buildCoursesContent(isIos)
              : _buildGradeSheetContent(isIos),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl(bool isIos) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: isIos
          ? CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedSegment,
              backgroundColor: const Color(0xFF1E1E1E),
              thumbColor: const Color(0xFF00E676).withValues(alpha: 0.3),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Курсы', style: TextStyle(fontSize: 14)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Ведомость', style: TextStyle(fontSize: 14)),
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
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSegment = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 0
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Курсы',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedSegment == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedSegment == 0
                                ? const Color(0xFF00E676)
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSegment = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 1
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Ведомость',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedSegment == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedSegment == 1
                                ? const Color(0xFF00E676)
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCoursesContent(bool isIos) {
    if (widget.isLoading) {
      return Center(
        child: isIos
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
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
            isIos
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    child: Row(
                      children: [
                        Icon(
                          _isEditing ? CupertinoIcons.check_mark : CupertinoIcons.pencil,
                          size: 16,
                          color: const Color(0xFF00E676),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isEditing ? 'Готово' : 'Редактировать',
                          style: const TextStyle(color: Color(0xFF00E676), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : TextButton.icon(
                    onPressed: () => setState(() => _isEditing = !_isEditing),
                    icon: Icon(
                      _isEditing ? Icons.check : Icons.edit,
                      size: 16,
                      color: const Color(0xFF00E676),
                    ),
                    label: Text(
                      _isEditing ? 'Готово' : 'Редактировать',
                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 12),
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
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      onPressed: () => widget.onArchive(course),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        isIos ? CupertinoIcons.line_horizontal_3 : Icons.drag_handle,
                        color: Colors.grey[600],
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
                color: Colors.grey[600],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Архив',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.archivedCourses.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                  ? IconButton(
                      tooltip: 'Вернуть',
                      icon: Icon(
                        isIos ? CupertinoIcons.archivebox_fill : Icons.unarchive,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      onPressed: () => widget.onRestore(course),
                    )
                  : Icon(
                      isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                      color: Colors.grey[600],
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildGradeSheetContent(bool isIos) {
    if (widget.isLoadingPerformance) {
      return Center(
        child: isIos
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
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
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет данных об оценках',
              style: TextStyle(
                color: Colors.grey[500],
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

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
    final isIos = Platform.isIOS;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: (isIos
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _buildContent(isIos),
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: _buildContent(isIos),
            )),
    );
  }

  Widget _buildContent(bool isIos) {
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
              _categoryIcon(course.category, isIos),
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
    );
  }

  IconData _categoryIcon(String category, bool isIos) {
    switch (category) {
      case 'mathematics':
        return isIos ? CupertinoIcons.function : Icons.functions;
      case 'development':
        return isIos ? CupertinoIcons.chevron_left_slash_chevron_right : Icons.code;
      case 'stem':
        return isIos ? CupertinoIcons.lab_flask : Icons.science;
      case 'general':
        return isIos ? CupertinoIcons.book : Icons.school;
      case 'withoutCategory':
      default:
        return isIos ? CupertinoIcons.tag : Icons.category;
    }
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

class _CourseGradeTile extends StatelessWidget {
  final StudentPerformanceCourse course;
  final VoidCallback onTap;

  const _CourseGradeTile({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final gradeColor = _getGradeColor(course.total);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: isIos
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _buildContent(isIos, gradeColor),
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: _buildContent(isIos, gradeColor),
            ),
    );
  }

  Widget _buildContent(bool isIos, Color gradeColor) {
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
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
            color: Colors.grey[600],
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

  String _getGradeDescription(int grade) {
    if (grade >= 8) return 'Отлично';
    if (grade >= 6) return 'Хорошо';
    if (grade >= 4) return 'Удовлетворительно';
    return 'Неудовлетворительно';
  }
}
