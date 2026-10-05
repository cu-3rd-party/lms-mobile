import 'package:cumobile/data/models/longread_material.dart';

class QuizQuestionType {
  static const singleChoice = 'singleChoice';
  static const multipleChoice = 'multipleChoice';
  static const stringMatch = 'stringMatch';
  static const numberMatch = 'numberMatch';
  static const openText = 'openText';
}

class QuizOption {
  final Object id;
  final String content;

  const QuizOption({required this.id, required this.content});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] ?? 0,
      content: parseRichContent(json['value'] ?? json['content']) ?? '',
    );
  }
}

class QuizPlayerQuestion {
  final int id;
  final String type;
  final String content;
  final double? maxScore;
  final int order;
  final List<QuizOption> options;
  final int? precision;

  const QuizPlayerQuestion({
    required this.id,
    required this.type,
    required this.content,
    required this.maxScore,
    required this.order,
    required this.options,
    this.precision,
  });

  factory QuizPlayerQuestion.fromJson(Map<String, dynamic> json) {
    return QuizPlayerQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      content: parseRichContent(json['content']) ?? '',
      maxScore: (json['score'] as num?)?.toDouble(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      options: (json['options'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QuizOption.fromJson)
          .toList(),
      precision: (json['precision'] as num?)?.toInt(),
    );
  }

  QuizPlayerQuestion withOrder(int order, List<QuizOption> options) {
    return QuizPlayerQuestion(
      id: id,
      type: type,
      content: content,
      maxScore: maxScore,
      order: order,
      options: options,
      precision: precision,
    );
  }
}

class QuizAttempt {
  final int id;
  final int number;
  final String state;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double? score;
  final Map<int, int> questionOrders;
  final Map<String, int> optionOrders;
  final Map<int, dynamic> answers;
  final Map<int, double?> results;

  const QuizAttempt({
    required this.id,
    required this.number,
    required this.state,
    this.startedAt,
    this.finishedAt,
    this.score,
    this.questionOrders = const {},
    this.optionOrders = const {},
    this.answers = const {},
    this.results = const {},
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final questionOrders = <int, int>{};
    final optionOrders = <String, int>{};
    for (final item in (json['questions'] as List? ?? const []).whereType<Map>()) {
      final questionId = (item['questionId'] as num?)?.toInt();
      final order = (item['order'] as num?)?.toInt();
      if (questionId != null && order != null) questionOrders[questionId] = order;
      for (final option in (item['options'] as List? ?? const []).whereType<Map>()) {
        final optionOrder = (option['order'] as num?)?.toInt();
        if (option['optionId'] != null && optionOrder != null) {
          optionOrders[option['optionId'].toString()] = optionOrder;
        }
      }
    }
    final answers = <int, dynamic>{};
    for (final item in (json['answers'] as List? ?? const []).whereType<Map>()) {
      final questionId = (item['questionId'] as num?)?.toInt();
      if (questionId != null) answers[questionId] = item['value'];
    }
    final results = <int, double?>{};
    for (final item in (json['results'] as List? ?? const []).whereType<Map>()) {
      final questionId = (item['questionId'] as num?)?.toInt();
      if (questionId != null) results[questionId] = (item['score'] as num?)?.toDouble();
    }
    return QuizAttempt(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: (json['number'] as num?)?.toInt() ?? 0,
      state: json['state']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      finishedAt: DateTime.tryParse(json['finishedAt']?.toString() ?? ''),
      score: (json['score'] as num?)?.toDouble(),
      questionOrders: questionOrders,
      optionOrders: optionOrders,
      answers: answers,
      results: results,
    );
  }
}

class QuizTask {
  final int id;
  final String state;
  final double? score;
  final double? maxScore;
  final DateTime? deadline;
  final DateTime? submitAt;
  final int? quizId;
  final int? quizSessionId;
  final int? currentAttemptId;
  final int? evaluatedAttemptId;
  final int? lastAttemptId;
  final Duration? timer;
  final int? attemptsLimit;
  final String? evaluationStrategy;

  const QuizTask({
    required this.id,
    required this.state,
    this.score,
    this.maxScore,
    this.deadline,
    this.submitAt,
    this.quizId,
    this.quizSessionId,
    this.currentAttemptId,
    this.evaluatedAttemptId,
    this.lastAttemptId,
    this.timer,
    this.attemptsLimit,
    this.evaluationStrategy,
  });

  factory QuizTask.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'] is Map ? json['exercise'] as Map : const {};
    final settings = exercise['settings'] is Map ? exercise['settings'] as Map : const {};
    return QuizTask(
      id: (json['id'] as num?)?.toInt() ?? 0,
      state: json['state']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble(),
      maxScore: (exercise['maxScore'] as num?)?.toDouble(),
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? ''),
      submitAt: DateTime.tryParse(json['submitAt']?.toString() ?? ''),
      quizId: (exercise['quizId'] as num?)?.toInt(),
      quizSessionId: (json['quizSessionId'] as num?)?.toInt(),
      currentAttemptId: (json['currentAttemptId'] as num?)?.toInt(),
      evaluatedAttemptId: (json['evaluatedAttemptId'] as num?)?.toInt(),
      lastAttemptId: (json['lastAttemptId'] as num?)?.toInt(),
      timer: parseTimer(exercise['timer']?.toString()),
      attemptsLimit: (settings['attemptsLimit'] as num?)?.toInt(),
      evaluationStrategy: settings['evaluationStrategy']?.toString(),
    );
  }

  static Duration? parseTimer(String? raw) {
    if (raw == null || raw.length < 2) return null;
    final parts = raw.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final seconds = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0;
    final duration = Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
    return duration == Duration.zero ? null : duration;
  }

  static const _answerableStates = {'inProgress', 'backlog', 'submitted', 'reworking'};

  bool get isAnswerableState => _answerableStates.contains(state);

  int? get displayAttemptId => currentAttemptId ?? evaluatedAttemptId ?? lastAttemptId;

  bool get canStartTask => state == 'backlog';

  bool get canStartAttempt =>
      state == 'inProgress' && currentAttemptId == null && quizSessionId != null;
}

class QuizActionResult {
  final bool success;
  final String? errorCode;

  const QuizActionResult(this.success, [this.errorCode]);

  String get errorMessage => switch (errorCode) {
        'attemptNotStarted' => 'Попытка не начата в этой задаче',
        'attemptsLimitReached' => 'Превышен лимит попыток',
        'hasActiveAttempt' => 'В сессии уже есть активная попытка',
        'invalidState' =>
          'Время истекло, ваши ответы были сохранены и отправлены на проверку',
        _ => 'Не удалось выполнить действие',
      };
}
