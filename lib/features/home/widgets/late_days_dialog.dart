import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';

/// Shows the late days extension dialog.
/// Returns the number of days to extend, or null if cancelled.
Future<int?> showLateDaysDialog({
  required BuildContext context,
  required String taskName,
  required String courseName,
  required DateTime? deadline,
  required int existingLateDays,
  required int lateDaysBalance,
}) {
  final maxDays = math.min(lateDaysBalance, 7 - existingLateDays);
  final c = AppColors.of(context);

  if (maxDays <= 0) {
    if (Platform.isIOS) {
      return showCupertinoDialog<int>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Перенос недоступен'),
          content: Text(
            lateDaysBalance <= 0
                ? 'У тебя не осталось дней для переноса'
                : 'Ты уже использовал максимум дней переноса для этого задания',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Перенос недоступен', style: TextStyle(color: c.textPrimary)),
        content: Text(
          lateDaysBalance <= 0
              ? 'У тебя не осталось дней для переноса'
              : 'Ты уже использовал максимум дней переноса для этого задания',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  if (Platform.isIOS) {
    return showCupertinoModalPopup<int>(
      context: context,
      builder: (context) {
        final cc = AppColors.of(context);
        return Container(
          decoration: BoxDecoration(
            color: cc.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: _LateDaysSheet(
            taskName: taskName,
            courseName: courseName,
            deadline: deadline,
            existingLateDays: existingLateDays,
            maxDays: maxDays,
          ),
        );
      },
    );
  }

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) => _LateDaysSheet(
      taskName: taskName,
      courseName: courseName,
      deadline: deadline,
      existingLateDays: existingLateDays,
      maxDays: maxDays,
    ),
  );
}

class _LateDaysSheet extends StatefulWidget {
  final String taskName;
  final String courseName;
  final DateTime? deadline;
  final int existingLateDays;
  final int maxDays;

  const _LateDaysSheet({
    required this.taskName,
    required this.courseName,
    required this.deadline,
    required this.existingLateDays,
    required this.maxDays,
  });

  @override
  State<_LateDaysSheet> createState() => _LateDaysSheetState();
}

class _LateDaysSheetState extends State<_LateDaysSheet> {
  late int _days;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = 1;
    _validate();
  }

  void _validate() {
    if (widget.deadline == null) {
      _error = null;
      return;
    }
    // deadline уже включает existingLateDays, добавляем только новые дни
    final newDeadline = widget.deadline!.add(Duration(days: _days));
    if (DateTime.now().isAfter(newDeadline)) {
      _error = 'Перенос на $_days дн. недостаточен — дедлайн всё равно будет просрочен';
    } else {
      _error = null;
    }
  }

  String _formatDeadline(DateTime? dl) {
    if (dl == null) return '—';
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final d = dl.toLocal();
    return '${d.day} ${months[d.month - 1]}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final c = AppColors.of(context);
    final newDeadline = widget.deadline?.add(Duration(days: _days));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Перенести дедлайн',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ты можешь перенести дедлайн задания на любое доступное количество дней',
              style: TextStyle(fontSize: 13, color: c.textTertiary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.taskName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.courseName,
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isIos ? CupertinoIcons.time : Icons.access_time,
                        size: 12,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Текущий дедлайн: ${_formatDeadline(widget.deadline)}',
                        style: TextStyle(fontSize: 11, color: c.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Количество дней (макс. ${widget.maxDays})',
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStepButton(isIos, Icons.remove, CupertinoIcons.minus, _days > 1, () {
                  setState(() {
                    _days = math.max(1, _days - 1);
                    _validate();
                  });
                }),
                const SizedBox(width: 12),
                Text(
                  '$_days',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                _buildStepButton(isIos, Icons.add, CupertinoIcons.plus, _days < widget.maxDays, () {
                  setState(() {
                    _days = math.min(widget.maxDays, _days + 1);
                    _validate();
                  });
                }),
                const Spacer(),
                if (newDeadline != null)
                  Text(
                    'Новый: ${_formatDeadline(newDeadline)}',
                    style: TextStyle(fontSize: 12, color: c.accent),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: c.danger),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isIos
                  ? CupertinoButton.filled(
                      onPressed: _error == null ? () => Navigator.pop(context, _days) : null,
                      child: const Text('Перенести'),
                    )
                  : ElevatedButton(
                      onPressed: _error == null ? () => Navigator.pop(context, _days) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: c.onAccent,
                        disabledBackgroundColor: c.border,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Перенести'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton(
    bool isIos,
    IconData materialIcon,
    IconData cupertinoIcon,
    bool enabled,
    VoidCallback onTap,
  ) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? c.surfaceVariant : c.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isIos ? cupertinoIcon : materialIcon,
          size: 18,
          color: enabled ? c.textPrimary : c.textDisabled,
        ),
      ),
    );
  }
}
