class StudentPerformanceCourse {
  final int id;
  final String name;
  final String? description;
  final int total;

  StudentPerformanceCourse({
    required this.id,
    required this.name,
    this.description,
    required this.total,
  });

  factory StudentPerformanceCourse.fromJson(Map<String, dynamic> json) {
    return StudentPerformanceCourse(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      total: json['total'] as int? ?? 0,
    );
  }

  String get cleanName {
    return name.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim();
  }
}

class StudentPerformanceResponse {
  final List<StudentPerformanceCourse> courses;

  StudentPerformanceResponse({required this.courses});

  factory StudentPerformanceResponse.fromJson(Map<String, dynamic> json) {
    final coursesList = (json['courses'] as List<dynamic>?)
            ?.map((e) => StudentPerformanceCourse.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return StudentPerformanceResponse(courses: coursesList);
  }
}

class CourseExerciseActivity {
  final int id;
  final String name;

  CourseExerciseActivity({
    required this.id,
    required this.name,
  });

  factory CourseExerciseActivity.fromJson(Map<String, dynamic> json) {
    return CourseExerciseActivity(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class CourseExerciseTheme {
  final int id;
  final String name;

  CourseExerciseTheme({
    required this.id,
    required this.name,
  });

  factory CourseExerciseTheme.fromJson(Map<String, dynamic> json) {
    return CourseExerciseTheme(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class CourseExercise {
  final int id;
  final String name;
  final String type;
  final CourseExerciseActivity? activity;
  final CourseExerciseTheme? theme;

  CourseExercise({
    required this.id,
    required this.name,
    required this.type,
    this.activity,
    this.theme,
  });

  factory CourseExercise.fromJson(Map<String, dynamic> json) {
    return CourseExercise(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String? ?? '',
      activity: json['activity'] != null
          ? CourseExerciseActivity.fromJson(json['activity'] as Map<String, dynamic>)
          : null,
      theme: json['theme'] != null
          ? CourseExerciseTheme.fromJson(json['theme'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CourseExercisesResponse {
  final int id;
  final String name;
  final bool isArchived;
  final List<CourseExercise> exercises;

  CourseExercisesResponse({
    required this.id,
    required this.name,
    required this.isArchived,
    required this.exercises,
  });

  factory CourseExercisesResponse.fromJson(Map<String, dynamic> json) {
    final exercisesList = (json['exercises'] as List<dynamic>?)
            ?.map((e) => CourseExercise.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CourseExercisesResponse(
      id: json['id'] as int,
      name: json['name'] as String,
      isArchived: json['isArchived'] as bool? ?? false,
      exercises: exercisesList,
    );
  }
}

class TaskScoreActivity {
  final int id;
  final String name;
  final double weight;
  final double? averageScoreThreshold;

  TaskScoreActivity({
    required this.id,
    required this.name,
    required this.weight,
    this.averageScoreThreshold,
  });

  factory TaskScoreActivity.fromJson(Map<String, dynamic> json) {
    return TaskScoreActivity(
      id: json['id'] as int,
      name: json['name'] as String,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      averageScoreThreshold: (json['averageScoreThreshold'] as num?)?.toDouble(),
    );
  }
}

class TaskScore {
  final int id;
  final String state;
  final double score;
  final String? scoreSkillLevel;
  final double? extraScore;
  final int exerciseId;
  final int maxScore;
  final TaskScoreActivity activity;

  TaskScore({
    required this.id,
    required this.state,
    required this.score,
    this.scoreSkillLevel,
    this.extraScore,
    required this.exerciseId,
    required this.maxScore,
    required this.activity,
  });

  factory TaskScore.fromJson(Map<String, dynamic> json) {
    return TaskScore(
      id: json['id'] as int,
      state: json['state'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      scoreSkillLevel: json['scoreSkillLevel'] as String?,
      extraScore: (json['extraScore'] as num?)?.toDouble(),
      exerciseId: json['exerciseId'] as int,
      maxScore: json['maxScore'] as int? ?? 10,
      activity: TaskScoreActivity.fromJson(json['activity'] as Map<String, dynamic>),
    );
  }
}

class CourseStudentPerformanceResponse {
  final List<TaskScore> tasks;

  CourseStudentPerformanceResponse({required this.tasks});

  factory CourseStudentPerformanceResponse.fromJson(Map<String, dynamic> json) {
    final tasksList = (json['tasks'] as List<dynamic>?)
            ?.map((e) => TaskScore.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CourseStudentPerformanceResponse(tasks: tasksList);
  }
}

class ExerciseWithScore {
  final CourseExercise exercise;
  final TaskScore? score;

  ExerciseWithScore({
    required this.exercise,
    this.score,
  });

  String get themeName => exercise.theme?.name ?? 'Без темы';
  String get activityName => exercise.activity?.name ?? 'Без активности';
  double get scoreValue => score?.score ?? 0.0;
  int get maxScore => score?.maxScore ?? 10;
  String get state => score?.state ?? 'none';
}

class ActivitySummary {
  final int activityId;
  final String activityName;
  final int count;
  final double averageScore;
  final double weight;

  ActivitySummary({
    required this.activityId,
    required this.activityName,
    required this.count,
    required this.averageScore,
    required this.weight,
  });

  double get totalContribution => averageScore * weight;
}
