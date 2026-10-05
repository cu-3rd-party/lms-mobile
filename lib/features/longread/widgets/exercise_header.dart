import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cumobile/core/theme/app_colors.dart';

class ExerciseHeader extends StatelessWidget {
  final String title;
  final String? statusLabel;
  final Color? statusColor;
  final DateTime? deadline;
  final double? score;
  final int? maxScore;
  final double? weight;
  final String? attemptsText;
  final bool showStatusDot;

  const ExerciseHeader({
    super.key,
    required this.title,
    this.statusLabel,
    this.statusColor,
    this.deadline,
    this.score,
    this.maxScore,
    this.weight,
    this.attemptsText,
    this.showStatusDot = true,
  });

  static final DateFormat _deadlineFormat = DateFormat("EE, dd MMMM 'в' HH:mm", 'ru_RU');

  static String pluralize(int value, String one, String few, String many) {
    final mod10 = value % 10;
    final mod100 = value % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  static String attemptsLabel(int? limit, String? strategy) {
    final attempts = limit == null
        ? 'Без ограничения попыток'
        : '$limit ${pluralize(limit, 'попытка', 'попытки', 'попыток')}';
    final result = switch (strategy) {
      'last' => 'Засчитаем последний результат',
      'best' => 'Засчитаем лучший результат',
      'first' => 'Засчитаем первый результат',
      'average' => 'Засчитаем средний результат',
      _ => null,
    };
    return result == null ? attempts : '$attempts · $result';
  }

  static String _formatNumber(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  String? get _deadlineText {
    final value = deadline;
    if (value == null) return null;
    final text = _deadlineFormat.format(value.toLocal());
    return 'Дедлайн: ${text[0].toUpperCase()}${text.substring(1)}';
  }

  String? get _scoreText {
    final max = maxScore;
    if (max == null) return null;
    final unit = pluralize(max, 'балл', 'балла', 'баллов');
    final value = score;
    return value == null ? '$max $unit' : '${_formatNumber(value)}/$max $unit';
  }

  String? get _weightText {
    final value = weight;
    if (value == null) return null;
    return 'Вес: ${_formatNumber(value * 100)}%';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final rows = <(IconData, String)>[
      if (_deadlineText != null)
        (isIos ? CupertinoIcons.calendar : Icons.calendar_today_outlined, _deadlineText!),
      if (_scoreText != null)
        (isIos ? CupertinoIcons.rosette : Icons.workspace_premium_outlined, _scoreText!),
      if (_weightText != null)
        (isIos ? CupertinoIcons.chart_pie : Icons.pie_chart_outline, _weightText!),
      if (attemptsText != null)
        (isIos ? CupertinoIcons.arrow_clockwise : Icons.refresh, attemptsText!),
    ];
    final badgeColor = statusColor ?? c.textTertiary;
    final badgeTextColor = showStatusDot ? badgeColor : c.textSecondary;
    final badgeBackground =
        showStatusDot ? badgeColor.withValues(alpha: 0.2) : c.surfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (statusLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showStatusDot) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  statusLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    color: badgeTextColor,
                    fontWeight: showStatusDot ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        for (final (icon, text) in rows) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: c.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
