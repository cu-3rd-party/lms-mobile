import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Перенос недоступен', style: TextStyle(color: Colors.white)),
        content: Text(
          lateDaysBalance <= 0
              ? 'У тебя не осталось дней для переноса'
              : 'Ты уже использовал максимум дней переноса для этого задания',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF00E676))),
          ),
        ],
      ),
    );
  }

  if (Platform.isIOS) {
    return showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _LateDaysSheet(
          taskName: taskName,
          courseName: courseName,
          deadline: deadline,
          existingLateDays: existingLateDays,
          maxDays: maxDays,
        ),
      ),
    );
  }

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
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
    final totalLateDays = widget.existingLateDays + _days;
    final newDeadline = widget.deadline!.add(Duration(days: totalLateDays));
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
    final totalLateDays = widget.existingLateDays + _days;
    final newDeadline = widget.deadline?.add(Duration(days: totalLateDays));

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
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Перенести дедлайн',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ты можешь перенести дедлайн задания на любое доступное количество дней',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.taskName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.courseName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isIos ? CupertinoIcons.time : Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Текущий дедлайн: ${_formatDeadline(widget.deadline?.add(Duration(days: widget.existingLateDays)))}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Количество дней (макс. ${widget.maxDays})',
              style: const TextStyle(fontSize: 13, color: Colors.white),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
                    style: const TextStyle(fontSize: 12, color: Color(0xFF00E676)),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
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
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey[700],
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
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF252525) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isIos ? cupertinoIcon : materialIcon,
          size: 18,
          color: enabled ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }
}
