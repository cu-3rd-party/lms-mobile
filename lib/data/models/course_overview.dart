class CourseOverview {
  final int id;
  final String name;
  final bool isArchived;
  final List<CourseTheme> themes;

  CourseOverview({
    required this.id,
    required this.name,
    required this.isArchived,
    required this.themes,
  });

  factory CourseOverview.fromJson(Map<String, dynamic> json) {
    return CourseOverview(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isArchived: json['isArchived'] ?? false,
      themes: (json['themes'] as List?)
              ?.map((e) => CourseTheme.fromJson(e))
              .toList() ??
          [],
    );
  }

  String get cleanName => name.replaceAll(RegExp(r'^[\u{1F300}-\u{1F9FF}]\s*', unicode: true), '');
}

class CourseTheme {
  final int id;
  final String name;
  final int order;
  final String state;
  final List<Longread> longreads;

  CourseTheme({
    required this.id,
    required this.name,
    required this.order,
    required this.state,
    required this.longreads,
  });

  factory CourseTheme.fromJson(Map<String, dynamic> json) {
    return CourseTheme(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      order: json['order'] ?? 0,
      state: json['state'] ?? '',
      longreads: (json['longreads'] as List?)
              ?.map((e) => Longread.fromJson(e))
              .toList() ??
          [],
    );
  }

  int get totalExercises => longreads.fold(0, (sum, lr) => sum + lr.exercises.length);

  bool get hasExercises => totalExercises > 0;
}

class Longread {
  final int id;
  final String type;
  final String name;
  final String state;
  final List<ThemeExercise> exercises;

  Longread({
    required this.id,
    required this.type,
    required this.name,
    required this.state,
    required this.exercises,
  });

  factory Longread.fromJson(Map<String, dynamic> json) {
    return Longread(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      exercises: (json['exercises'] as List?)
              ?.map((e) => ThemeExercise.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ThemeExercise {
  final int id;
  final String name;
  final int maxScore;
  final DateTime? deadline;
  final ExerciseActivity? activity;

  ThemeExercise({
    required this.id,
    required this.name,
    required this.maxScore,
    this.deadline,
    this.activity,
  });

  factory ThemeExercise.fromJson(Map<String, dynamic> json) {
    return ThemeExercise(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      maxScore: json['maxScore'] ?? 0,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      activity: json['activity'] != null ? ExerciseActivity.fromJson(json['activity']) : null,
    );
  }

  bool get isOverdue => deadline != null && DateTime.now().isAfter(deadline!);

  String get formattedDeadline {
    if (deadline == null) return '';
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final d = deadline!.toLocal();
    return '${d.day} ${months[d.month - 1]}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class ExerciseActivity {
  final int id;
  final String name;
  final double weight;

  ExerciseActivity({
    required this.id,
    required this.name,
    required this.weight,
  });

  factory ExerciseActivity.fromJson(Map<String, dynamic> json) {
    return ExerciseActivity(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
    );
  }
}
