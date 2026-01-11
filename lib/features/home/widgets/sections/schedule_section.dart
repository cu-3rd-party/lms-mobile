import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cumobile/data/models/class_data.dart';

class ScheduleSection extends StatelessWidget {
  final DateTime date;
  final List<ClassData> classes;
  final bool isLoading;
  final String? emptyMessage;
  final ScrollController scrollController;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onSelectDate;
  final VoidCallback onGoToToday;
  final void Function(String) onOpenLink;

  static final DateFormat _dateFormat = DateFormat('EEEE, d MMMM', 'ru_RU');
  static const double _hourHeight = 80.0;

  const ScheduleSection({
    super.key,
    required this.date,
    required this.classes,
    required this.isLoading,
    this.emptyMessage,
    required this.scrollController,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onSelectDate,
    required this.onGoToToday,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    if (classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    emptyMessage ?? 'Нет занятий на сегодня',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    const minHour = 0;
    const maxHour = 23;
    final timeSlots = [
      for (var h = minHour; h <= maxHour; h++) '${h.toString().padLeft(2, '0')}:00'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: SingleChildScrollView(
              controller: scrollController,
              child: SizedBox(
                height: timeSlots.length * _hourHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    _buildTimeGrid(timeSlots),
                    ...classes.map((classData) => _buildPositionedClass(classData)),
                    if (_isSameDay(date, DateTime.now()))
                      _buildNowIndicator(DateTime.now()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Расписание',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _dateFormat.format(date).toLowerCase(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        if (!isToday) ...[
          TextButton(
            onPressed: onGoToToday,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: const Color(0xFF00E676),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Сегодня',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
        ],
        _navIconButton(
          icon: Icons.chevron_left,
          tooltip: 'Предыдущий день',
          onTap: onPreviousDay,
        ),
        const SizedBox(width: 4),
        _navIconButton(
          icon: Icons.calendar_today,
          tooltip: 'Выбрать дату',
          onTap: onSelectDate,
        ),
        const SizedBox(width: 4),
        _navIconButton(
          icon: Icons.chevron_right,
          tooltip: 'Следующий день',
          onTap: onNextDay,
        ),
      ],
    );
  }

  Widget _navIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 22,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[400], size: size),
        ),
      ),
    );
  }

  Widget _buildTimeGrid(List<String> timeSlots) {
    return Column(
      children: timeSlots.map((time) {
        return SizedBox(
          height: _hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 11),
                  height: 1,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPositionedClass(ClassData classData) {
    final startParts = classData.startTime.split(':');
    final endParts = classData.endTime.split(':');
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);

    final startTimeInMinutes = startHour * 60 + startMinute;
    final endTimeInMinutes = endHour * 60 + endMinute;
    final durationInMinutes = endTimeInMinutes - startTimeInMinutes;

    final topOffset = startTimeInMinutes / 60.0 * _hourHeight;
    final calculatedHeight = durationInMinutes / 60.0 * _hourHeight;
    final height = (calculatedHeight < 70 ? 70.0 : calculatedHeight).toDouble();

    return Positioned(
      left: 50.0,
      right: 0.0,
      top: topOffset,
      height: height,
      child: _ClassCard(
        classData: classData,
        onOpenLink: onOpenLink,
      ),
    );
  }

  Widget _buildNowIndicator(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    final topOffset = minutes / 60.0 * _hourHeight;
    return Positioned(
      top: topOffset,
      left: 50,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF00E676),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF00E676),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ClassCard extends StatelessWidget {
  final ClassData classData;
  final void Function(String) onOpenLink;

  const _ClassCard({
    required this.classData,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final timeRange = '${classData.startTime} - ${classData.endTime}';
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        onTap: classData.link != null && classData.link!.isNotEmpty
            ? () => onOpenLink(classData.link!)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.wifi, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      classData.room,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      timeRange,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (classData.link != null && classData.link!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.link, size: 14, color: Color(0xFF00E676)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(Icons.star, size: 12, color: Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final title = classData.type.isNotEmpty
                                  ? '(${classData.type}) ${classData.title}'
                                  : classData.title;
                              final fontSize = _fitTitleFontSize(context, title, constraints.maxWidth);
                              return Text(
                                title,
                                style: TextStyle(
                                  fontSize: fontSize - 1,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        if (classData.professor != null &&
                            classData.professor!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            classData.professor!,
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (classData.badge != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        classData.badge!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _fitTitleFontSize(BuildContext context, String text, double maxWidth) {
    const maxSize = 13.0;
    const minSize = 10.0;
    var low = minSize;
    var high = maxSize;
    var best = minSize;
    while ((high - low) > 0.2) {
      final mid = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: mid, fontWeight: FontWeight.w500),
        ),
        maxLines: 2,
        textDirection: Directionality.of(context),
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      if (painter.didExceedMaxLines) {
        high = mid;
      } else {
        best = mid;
        low = mid;
      }
    }
    return best;
  }
}
