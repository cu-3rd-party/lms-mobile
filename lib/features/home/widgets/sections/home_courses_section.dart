import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
              if (courses.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${courses.length}',
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
          if (isLoading)
            Center(
              child: isIos
                  ? const CupertinoActivityIndicator(
                      radius: 14,
                      color: Color(0xFF00E676),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          else if (courses.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isIos ? CupertinoIcons.book : Icons.school,
                    color: Colors.grey[600],
                    size: 20,
                  ),
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
