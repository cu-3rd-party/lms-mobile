class ExamItem {
  final String name;
  final String rawDate;
  final DateTime? date;
  final int? weekNumber;

  const ExamItem({
    required this.name,
    required this.rawDate,
    this.date,
    this.weekNumber,
  });

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? '').toString();
    return ExamItem(
      name: (json['name'] ?? '').toString().trim(),
      rawDate: rawDate,
      date: parseDate(rawDate),
    );
  }

  ExamItem withWeek(int? week) => ExamItem(
        name: name,
        rawDate: rawDate,
        date: date,
        weekNumber: week,
      );

  static DateTime? parseDate(String raw, {DateTime? now}) {
    final match = RegExp(r'^\s*(\d{1,2})[\s.\-/]+(\d{1,2})\s*$').firstMatch(raw);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (day == null || month == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final year = (now ?? DateTime.now()).year;
    final candidate = DateTime(year, month, day);
    if (candidate.month != month || candidate.day != day) return null;
    return candidate;
  }
}
