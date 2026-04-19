import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/features/home/widgets/cards/course_card.dart';

class HomeCoursesSection extends StatelessWidget {
  final List<Course> courses;
  final bool isLoading;
  final void Function(Course) onOpenCourse;

  const HomeCoursesSection({
    super.key,
    required this.courses,
    required this.isLoading,
    required this.onOpenCourse,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Курсы',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              if (courses.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${courses.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            Center(
              child: isIos
                  ? CupertinoActivityIndicator(
                      radius: 14,
                      color: c.accent,
                    )
                  : CircularProgressIndicator(color: c.accent),
            )
          else if (courses.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isIos ? CupertinoIcons.book : Icons.school,
                    color: c.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Нет активных курсов',
                    style: TextStyle(color: c.textTertiary, fontSize: 14),
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
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return CourseCard(
                  title: course.cleanName,
                  categoryLabel: course.categoryName,
                  categoryColor: course.categoryColor,
                  categoryIcon: course.categoryIconAdaptive,
                  onTap: () => onOpenCourse(course),
                );
              },
            ),
        ],
      ),
    );
  }

}
