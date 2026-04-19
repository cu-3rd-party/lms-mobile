import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';

class CourseCard extends StatelessWidget {
  final String title;
  final String categoryLabel;
  final Color categoryColor;
  final IconData categoryIcon;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.title,
    required this.categoryLabel,
    required this.categoryColor,
    required this.categoryIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
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
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textTertiary,
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
                    color: categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    categoryIcon,
                    size: 14,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
