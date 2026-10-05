import 'dart:math';
import 'dart:typed_data';

import 'package:cumobile/data/models/attendance.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_extras.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/exam_item.dart';
import 'package:cumobile/data/models/longread_material.dart';
import 'package:cumobile/data/models/notification_item.dart';
import 'package:cumobile/data/models/quiz.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_performance.dart';
import 'package:cumobile/data/models/student_profile.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/data/models/task_comment.dart';
import 'package:cumobile/data/models/task_details.dart';
import 'package:cumobile/data/models/task_event.dart';
import 'package:cumobile/data/services/ical_service.dart';

class _DemoActivity {
  final int id;
  final String name;
  final double weight;

  const _DemoActivity(this.id, this.name, this.weight);
}

class _DemoLongread {
  final int id;
  final String name;
  final String html;

  const _DemoLongread(this.id, this.name, this.html);
}

class _DemoTheme {
  final int id;
  final int courseId;
  final String name;
  final List<_DemoLongread> longreads;

  const _DemoTheme(this.id, this.courseId, this.name, this.longreads);
}

class _DemoHost {
  final String id;
  final String name;
  final String email;

  const _DemoHost(this.id, this.name, this.email);
}

class _DemoSlot {
  final int courseId;
  final int weekday;
  final String start;
  final String end;
  final String type;
  final String format;
  final String room;
  final _DemoHost host;

  const _DemoSlot(
    this.courseId,
    this.weekday,
    this.start,
    this.end,
    this.type,
    this.format,
    this.room,
    this.host,
  );
}

class _DemoTask {
  final int id;
  final int exerciseId;
  final int courseId;
  final int themeId;
  final int longreadId;
  final int materialId;
  final String name;
  final String type;
  final _DemoActivity activity;
  final String description;
  final DateTime createdAt;
  final DateTime baseDeadline;
  final bool isLateDaysEnabled;
  final int maxScore = 10;
  String state;
  double? score;
  DateTime? submitAt;
  String? solutionUrl;
  List<MaterialAttachment> solutionAttachments = [];
  int lateDays;
  final List<QuizPlayerQuestion> quizQuestions;
  final Map<int, Object> correctAnswers;
  final int attemptsLimit;
  final String evaluationStrategy;
  final Duration? timer;
  int? currentAttemptId;
  int? lastAttemptId;
  final List<TaskEvent> events = [];
  final List<TaskComment> comments = [];

  _DemoTask({
    required this.id,
    required this.exerciseId,
    required this.courseId,
    required this.themeId,
    required this.longreadId,
    required this.materialId,
    required this.name,
    required this.type,
    required this.activity,
    required this.description,
    required this.createdAt,
    required this.baseDeadline,
    required this.state,
    this.score,
    this.submitAt,
    this.solutionUrl,
    this.isLateDaysEnabled = false,
    this.lateDays = 0,
    this.quizQuestions = const [],
    this.correctAnswers = const {},
    this.attemptsLimit = 1,
    this.evaluationStrategy = 'last',
    this.timer,
  });

  bool get isQuiz => type == 'questions';

  int get quizSessionId => id + 50000;

  DateTime get deadline => baseDeadline.add(Duration(days: lateDays));
}

class _DemoAttempt {
  final int id;
  final int taskId;
  final int number;
  final DateTime startedAt;
  DateTime? finishedAt;
  String state = 'inProgress';
  final Map<int, Object?> answers = {};
  final Map<int, double?> results = {};

  _DemoAttempt(this.id, this.taskId, this.number, this.startedAt);
}

class DemoService {
  static const _reviewer = _DemoHost(
    'demo-host-1',
    'Петрова Анна Сергеевна',
    'a.petrova@centraluniversity.ru',
  );
  static const _lecturer = _DemoHost(
    'demo-host-2',
    'Иванов Дмитрий Олегович',
    'd.ivanov@centraluniversity.ru',
  );
  static const _mentor = _DemoHost(
    'demo-host-3',
    'Смирнова Мария Андреевна',
    'm.smirnova@centraluniversity.ru',
  );
  static const _recordingUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  bool _isDemoMode = false;
  int _lateDaysBalance = 5;
  Uint8List? _avatar;
  int _nextId = 100000;
  final Map<int, _DemoTask> _tasks = {};
  final Map<int, _DemoAttempt> _attempts = {};

  bool get isDemoMode => _isDemoMode;

  void enableDemo() {
    _isDemoMode = true;
    _seed();
  }

  void exitDemo() {
    _isDemoMode = false;
    _tasks.clear();
    _avatar = null;
  }

  static final List<Course> _courses = [
    Course(
      id: 1001,
      name: '💻 Основы программирования',
      state: 'active',
      category: 'development',
      categoryCover: '',
      isArchived: false,
    ),
    Course(
      id: 1002,
      name: '📐 Линейная алгебра',
      state: 'active',
      category: 'mathematics',
      categoryCover: '',
      isArchived: false,
    ),
    Course(
      id: 1003,
      name: '🔬 Основы Data Science',
      state: 'active',
      category: 'stem',
      categoryCover: '',
      isArchived: false,
    ),
    Course(
      id: 1004,
      name: '🤝 Командная работа',
      state: 'active',
      category: 'softSkills',
      categoryCover: '',
      isArchived: false,
    ),
    Course(
      id: 1005,
      name: '📚 Введение в алгоритмы',
      state: 'archived',
      category: 'development',
      categoryCover: '',
      isArchived: true,
    ),
  ];

  static _DemoActivity _homework(int courseId) =>
      _DemoActivity(courseId * 10 + 1, 'Домашние задания', 0.6);

  static _DemoActivity _control(int courseId) =>
      _DemoActivity(courseId * 10 + 2, 'Контрольные работы', 0.4);

  static const List<_DemoTheme> _themes = [
    _DemoTheme(6001, 1001, 'Введение в разработку', [
      _DemoLongread(7001, 'Git и командная строка', _gitHtml),
    ]),
    _DemoTheme(6002, 1001, 'Алгоритмы', [
      _DemoLongread(7002, 'Сортировки', _sortHtml),
      _DemoLongread(7003, 'Рекурсия', _recursionHtml),
    ]),
    _DemoTheme(6003, 1002, 'Матрицы', [
      _DemoLongread(7004, 'Матрицы и определители', _matrixHtml),
    ]),
    _DemoTheme(6004, 1002, 'Векторные пространства', [
      _DemoLongread(7005, 'Базис и размерность', _basisHtml),
    ]),
    _DemoTheme(6005, 1003, 'Работа с данными', [
      _DemoLongread(7006, 'Pandas: первые шаги', _pandasHtml),
      _DemoLongread(7007, 'Визуализация', _vizHtml),
    ]),
    _DemoTheme(6006, 1004, 'Коммуникация', [
      _DemoLongread(7008, 'Публичные выступления', _speechHtml),
    ]),
    _DemoTheme(6007, 1005, 'Асимптотический анализ', [
      _DemoLongread(7009, 'O-нотация', _bigOHtml),
    ]),
  ];

  static const List<_DemoSlot> _slots = [
    _DemoSlot(
      1001,
      DateTime.monday,
      '10:00',
      '11:30',
      'lecture',
      'offline',
      'S304',
      _lecturer,
    ),
    _DemoSlot(
      1001,
      DateTime.wednesday,
      '12:00',
      '13:30',
      'seminar',
      'offline',
      'N318',
      _reviewer,
    ),
    _DemoSlot(
      1002,
      DateTime.tuesday,
      '09:00',
      '10:30',
      'lecture',
      'offline',
      'E301',
      _lecturer,
    ),
    _DemoSlot(
      1002,
      DateTime.thursday,
      '11:00',
      '12:30',
      'seminar',
      'offline',
      'W316',
      _reviewer,
    ),
    _DemoSlot(
      1003,
      DateTime.monday,
      '14:00',
      '15:30',
      'seminar',
      'online',
      'S203',
      _mentor,
    ),
    _DemoSlot(
      1003,
      DateTime.friday,
      '10:00',
      '11:30',
      'lecture',
      'offline',
      'S304',
      _lecturer,
    ),
    _DemoSlot(
      1004,
      DateTime.wednesday,
      '15:00',
      '16:30',
      'seminar',
      'offline',
      'N320',
      _mentor,
    ),
  ];

  void _seed() {
    _tasks.clear();
    _attempts.clear();
    _lateDaysBalance = 5;
    _avatar = null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59);

    void add(_DemoTask task) => _tasks[task.id] = task;

    add(
      _DemoTask(
        id: 2001,
        exerciseId: 3001,
        courseId: 1001,
        themeId: 6002,
        longreadId: 7002,
        materialId: 9002,
        name: 'Алгоритм сортировки',
        type: 'coding',
        activity: _homework(1001),
        description:
            '<p>Реализуйте сортировку слиянием для списка целых чисел. '
            'Решение оформите в виде репозитория и пришлите ссылку.</p>',
        createdAt: now.subtract(const Duration(days: 6)),
        baseDeadline: today.add(const Duration(days: 3)),
        state: 'inProgress',
        isLateDaysEnabled: true,
      ),
    );
    add(
      _DemoTask(
        id: 2002,
        exerciseId: 3002,
        courseId: 1002,
        themeId: 6003,
        longreadId: 7004,
        materialId: 9004,
        name: 'Матрицы и определители',
        type: 'essay',
        activity: _homework(1002),
        description:
            '<p>Вычислите определители матриц из условия и проверьте '
            'результат разложением по строке.</p>',
        createdAt: now.subtract(const Duration(days: 2)),
        baseDeadline: today.add(const Duration(days: 7)),
        state: 'backlog',
        isLateDaysEnabled: true,
      ),
    );
    add(
      _DemoTask(
        id: 2003,
        exerciseId: 3003,
        courseId: 1003,
        themeId: 6005,
        longreadId: 7006,
        materialId: 9006,
        name: 'Анализ датасета',
        type: 'coding',
        activity: _homework(1003),
        description:
            '<p>Загрузите датасет о поездках такси, посчитайте основные '
            'статистики и опишите три интересных наблюдения.</p>',
        createdAt: now.subtract(const Duration(days: 9)),
        baseDeadline: today.subtract(const Duration(days: 1)),
        state: 'review',
        submitAt: now.subtract(const Duration(days: 2)),
        solutionUrl: 'https://github.com/demo-student/taxi-analysis',
      ),
    );
    add(
      _DemoTask(
        id: 2004,
        exerciseId: 3004,
        courseId: 1001,
        themeId: 6001,
        longreadId: 7001,
        materialId: 9001,
        name: 'Введение в Git',
        type: 'coding',
        activity: _homework(1001),
        description:
            '<p>Создайте репозиторий, сделайте несколько коммитов в '
            'отдельной ветке и откройте pull request.</p>',
        createdAt: now.subtract(const Duration(days: 20)),
        baseDeadline: today.subtract(const Duration(days: 10)),
        state: 'evaluated',
        score: 9,
        submitAt: now.subtract(const Duration(days: 12)),
        solutionUrl: 'https://github.com/demo-student/git-intro',
      ),
    );
    add(
      _DemoTask(
        id: 2005,
        exerciseId: 3005,
        courseId: 1004,
        themeId: 6006,
        longreadId: 7008,
        materialId: 9008,
        name: 'Публичное выступление',
        type: 'essay',
        activity: _control(1004),
        description:
            '<p>Подготовьте пятиминутное выступление на свободную тему '
            'и загрузите запись.</p>',
        createdAt: now.subtract(const Duration(days: 18)),
        baseDeadline: today.subtract(const Duration(days: 7)),
        state: 'failed',
        score: 0,
        isLateDaysEnabled: true,
        lateDays: 2,
      ),
    );
    add(
      _DemoTask(
        id: 2006,
        exerciseId: 3006,
        courseId: 1001,
        themeId: 6002,
        longreadId: 7003,
        materialId: 9003,
        name: 'Рекурсивные функции',
        type: 'coding',
        activity: _control(1001),
        description:
            '<p>Напишите рекурсивные функции для чисел Фибоначчи, '
            'факториала и обхода дерева.</p>',
        createdAt: now.subtract(const Duration(days: 1)),
        baseDeadline: today.add(const Duration(days: 12)),
        state: 'backlog',
        isLateDaysEnabled: true,
      ),
    );
    add(
      _DemoTask(
        id: 2007,
        exerciseId: 3007,
        courseId: 1002,
        themeId: 6004,
        longreadId: 7005,
        materialId: 9005,
        name: 'Базис и размерность',
        type: 'essay',
        activity: _control(1002),
        description:
            '<p>Найдите базис и размерность подпространства, '
            'заданного системой уравнений.</p>',
        createdAt: now.subtract(const Duration(days: 15)),
        baseDeadline: today.subtract(const Duration(days: 6)),
        state: 'evaluated',
        score: 8,
        submitAt: now.subtract(const Duration(days: 7)),
      ),
    );
    add(
      _DemoTask(
        id: 2008,
        exerciseId: 3008,
        courseId: 1003,
        themeId: 6005,
        longreadId: 7007,
        materialId: 9007,
        name: 'Визуализация данных',
        type: 'coding',
        activity: _control(1003),
        description:
            '<p>Постройте три графика по датасету из предыдущего задания '
            'и объясните, что на них видно.</p>',
        createdAt: now.subtract(const Duration(days: 8)),
        baseDeadline: today.add(const Duration(days: 2)),
        state: 'reworking',
        submitAt: now.subtract(const Duration(days: 3)),
        solutionUrl: 'https://github.com/demo-student/taxi-viz',
      ),
    );
    add(
      _DemoTask(
        id: 2009,
        exerciseId: 3009,
        courseId: 1005,
        themeId: 6007,
        longreadId: 7009,
        materialId: 9009,
        name: 'Оценка сложности',
        type: 'essay',
        activity: _homework(1005),
        description:
            '<p>Оцените асимптотическую сложность алгоритмов из условия.</p>',
        createdAt: now.subtract(const Duration(days: 120)),
        baseDeadline: today.subtract(const Duration(days: 110)),
        state: 'evaluated',
        score: 10,
        submitAt: now.subtract(const Duration(days: 112)),
      ),
    );

    add(_DemoTask(
      id: 2010,
      exerciseId: 3010,
      courseId: 1004,
      themeId: 6006,
      longreadId: 7008,
      materialId: 9010,
      name: 'Вопрос на занятии 3',
      type: 'questions',
      activity: _homework(1004),
      description: '',
      createdAt: now.subtract(const Duration(days: 4)),
      baseDeadline: today.subtract(const Duration(days: 1)),
      state: 'review',
      submitAt: now.subtract(const Duration(days: 2)),
      quizQuestions: const [
        QuizPlayerQuestion(
          id: 5001,
          type: QuizQuestionType.openText,
          content: '<p>Какой приём помогает удержать внимание аудитории в начале выступления?</p>',
          maxScore: 10,
          order: 1,
          options: [],
        ),
      ],
    ));
    add(_DemoTask(
      id: 2011,
      exerciseId: 3011,
      courseId: 1001,
      themeId: 6001,
      longreadId: 7001,
      materialId: 9011,
      name: 'Тест: основы Git',
      type: 'questions',
      activity: _control(1001),
      description: '<p>Короткий тест по материалам лонгрида. На прохождение даётся 15 минут.</p>',
      createdAt: now.subtract(const Duration(days: 1)),
      baseDeadline: today.add(const Duration(days: 5)),
      state: 'backlog',
      timer: const Duration(minutes: 15),
      attemptsLimit: 1,
      evaluationStrategy: 'best',
      quizQuestions: const [
        QuizPlayerQuestion(
          id: 5101,
          type: QuizQuestionType.singleChoice,
          content: '<p>Какая команда создаёт новую ветку и сразу переключается на неё?</p>',
          maxScore: 2,
          order: 1,
          options: [
            QuizOption(id: 1, content: '<p><code>git branch -d feature</code></p>'),
            QuizOption(id: 2, content: '<p><code>git checkout -b feature</code></p>'),
            QuizOption(id: 3, content: '<p><code>git merge feature</code></p>'),
          ],
        ),
        QuizPlayerQuestion(
          id: 5102,
          type: QuizQuestionType.multipleChoice,
          content: '<p>Какие команды отправляют или получают данные с удалённого репозитория?</p>',
          maxScore: 2,
          order: 2,
          options: [
            QuizOption(id: 11, content: '<p><code>git push</code></p>'),
            QuizOption(id: 12, content: '<p><code>git commit</code></p>'),
            QuizOption(id: 13, content: '<p><code>git pull</code></p>'),
            QuizOption(id: 14, content: '<p><code>git status</code></p>'),
          ],
        ),
        QuizPlayerQuestion(
          id: 5103,
          type: QuizQuestionType.stringMatch,
          content: '<p>Какой командой посмотреть историю коммитов? Введите команду целиком.</p>',
          maxScore: 2,
          order: 3,
          options: [],
        ),
        QuizPlayerQuestion(
          id: 5104,
          type: QuizQuestionType.numberMatch,
          content: '<p>Сколько родительских коммитов у обычного merge-коммита двух веток?</p>',
          maxScore: 2,
          order: 4,
          options: [],
          precision: 0,
        ),
        QuizPlayerQuestion(
          id: 5105,
          type: QuizQuestionType.openText,
          content: '<p>Зачем команды используют pull request вместо прямого push в main?</p>',
          maxScore: 2,
          order: 5,
          options: [],
        ),
      ],
      correctAnswers: const {
        5101: 2,
        5102: [11, 13],
        5103: 'git log',
        5104: 2,
      },
    ));

    for (final task in _tasks.values) {
      _seedHistory(task);
    }

    final speechQuiz = _tasks[2010]!;
    final speechAttempt = _createAttempt(speechQuiz, now.subtract(const Duration(days: 2, minutes: 5)));
    speechAttempt.answers[5001] = '<p>Начать с вопроса к залу или неожиданного факта, '
        'который связан с главной мыслью выступления.</p>';
    _finishAttempt(speechQuiz, speechAttempt, now.subtract(const Duration(days: 2)));

    _tasks[2003]!.comments.add(
      _comment(
        'Добавил в README описание, как запустить ноутбук.',
        now.subtract(const Duration(days: 2)),
        fromStudent: true,
      ),
    );
    _tasks[2004]!.comments.add(
      _comment(
        'Отличная работа! Не забывайте писать осмысленные сообщения коммитов.',
        now.subtract(const Duration(days: 10)),
      ),
    );
    _tasks[2010]!.comments.add(
      _comment(
        'Хороший приём. Попробуйте ещё связать вопрос с темой выступления, разберём на семинаре.',
        now.subtract(const Duration(days: 1)),
      ),
    );
    _tasks[2008]!.comments.add(
      _comment(
        'Подпишите оси на графиках и добавьте легенду, после этого отправляйте снова.',
        now.subtract(const Duration(days: 1)),
      ),
    );
  }

  void _seedHistory(_DemoTask task) {
    _event(task, 'taskCreated', task.createdAt, system: true);
    if (task.state == 'backlog') return;
    _event(task, 'taskStarted', task.createdAt.add(const Duration(hours: 5)));
    if (task.lateDays > 0) {
      _event(
        task,
        'taskLateDaysProlong',
        task.createdAt.add(const Duration(days: 3)),
        lateDays: task.lateDays,
      );
    }
    final submitAt = task.submitAt;
    if (submitAt == null) return;
    _event(task, 'solutionAttached', submitAt);
    _event(task, 'taskCompleted', submitAt);
    _event(
      task,
      'reviewerAssigned',
      submitAt.add(const Duration(hours: 2)),
      system: true,
    );
    if (task.state == 'evaluated') {
      _event(
        task,
        'taskEvaluated',
        submitAt.add(const Duration(days: 1)),
        fromReviewer: true,
      );
    }
  }

  void _event(
    _DemoTask task,
    String type,
    DateTime at, {
    bool system = false,
    bool fromReviewer = false,
    int? lateDays,
  }) {
    final actorName = system
        ? 'System'
        : fromReviewer
        ? _reviewer.name
        : 'Студент Демо Режимович';
    final actorEmail = system
        ? 'system@cu.ru'
        : fromReviewer
        ? _reviewer.email
        : 'demo.student@edu.centraluniversity.ru';
    final estimation = TaskEventEstimation(
      deadline: task.deadline,
      maxScore: task.maxScore,
      activityName: task.activity.name,
      activityWeight: task.activity.weight,
    );
    task.events.add(
      TaskEvent(
        id: 'demo-event-${_nextId++}',
        occurredOn: at,
        type: type,
        actorName: actorName,
        actorEmail: actorEmail,
        content: TaskEventContent(
          state: type == 'taskCreated' ? 'backlog' : task.state,
          taskState: type == 'taskCreated' ? 'backlog' : null,
          estimation: estimation,
          score: type == 'taskEvaluated' && task.score != null
              ? TaskEventScore(value: task.score)
              : null,
          attachments: type == 'solutionAttached'
              ? task.solutionAttachments
              : const [],
          solutionUrl: type == 'solutionAttached' ? task.solutionUrl : null,
          reviewerName: type == 'reviewerAssigned' ? _reviewer.name : null,
          lateDaysValue: lateDays,
          contentDeadline: type == 'taskLateDaysProlong' ? task.deadline : null,
        ),
      ),
    );
  }

  TaskComment _comment(
    String text,
    DateTime at, {
    bool fromStudent = false,
    List<MaterialAttachment> attachments = const [],
  }) {
    return TaskComment(
      id: '${_nextId++}',
      content: text.startsWith('<') ? text : '<p>$text</p>',
      sender: fromStudent
          ? CommentSender(
              id: 'demo-001',
              email: 'demo.student@edu.centraluniversity.ru',
              name: 'Студент Демо Режимович',
            )
          : CommentSender(
              id: _reviewer.id,
              email: _reviewer.email,
              name: _reviewer.name,
            ),
      createdAt: at,
      attachments: attachments,
    );
  }

  Course? _course(int id) {
    for (final course in _courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  StudentTask _toStudentTask(_DemoTask task) {
    final course = _course(task.courseId)!;
    return StudentTask(
      id: task.id,
      state: task.state,
      score: task.score,
      deadline: task.deadline,
      submitAt: task.submitAt,
      exercise: TaskExercise(
        id: task.exerciseId,
        name: task.name,
        type: task.type,
        maxScore: task.maxScore,
        deadline: task.baseDeadline,
      ),
      course: TaskCourse(
        id: course.id,
        name: course.name,
        isArchived: course.isArchived,
      ),
      isLateDaysEnabled: task.isLateDaysEnabled,
      lateDays: task.lateDays,
    );
  }

  StudentProfile demoProfile() {
    return StudentProfile(
      id: 'demo-001',
      firstName: 'Демо',
      lastName: 'Студент',
      middleName: 'Режимович',
      birthdate: '2002-05-15',
      birthPlace: 'Москва',
      telegram: 'demo_student',
      timeLogin: 'demo.student',
      inn: '123456789012',
      snils: '12345678901',
      course: 2,
      gender: 'Male',
      enrollmentPhase: 'Study',
      educationLevel: 'Bachelor',
      emails: [
        EmailInfo(
          value: 'demo.student@edu.centraluniversity.ru',
          type: 'university',
        ),
        EmailInfo(value: 'demo@example.com', type: 'personal'),
      ],
      phones: [PhoneInfo(value: '79001234567', type: 'mobile')],
    );
  }

  Uint8List? demoAvatar() => _avatar;

  bool uploadAvatar(Uint8List bytes) {
    _avatar = bytes;
    return true;
  }

  bool deleteAvatar() {
    _avatar = null;
    return true;
  }

  StudentLmsProfile demoLmsProfile() {
    return StudentLmsProfile(
      id: 'demo-lms-001',
      lastName: 'Студент',
      firstName: 'Демо',
      middleName: 'Режимович',
      universityEmail: 'demo.student@edu.centraluniversity.ru',
      timeAccount: 'demo.student',
      studyStartYear: 2023,
      studyLevel: 'Bachelor',
      lateDaysBalance: _lateDaysBalance,
    );
  }

  List<Course> demoCourses() => List.of(_courses);

  List<StudentTask> demoTasks({
    bool inProgress = true,
    bool review = false,
    bool backlog = true,
    bool failed = false,
    bool evaluated = false,
  }) {
    final states = <String>{
      if (inProgress) ...['inProgress', 'submitted', 'reworking'],
      if (review) 'review',
      if (backlog) 'backlog',
      if (failed) 'failed',
      if (evaluated) 'evaluated',
    };
    return _tasks.values
        .where((t) => states.contains(t.state))
        .map(_toStudentTask)
        .toList();
  }

  List<StudentTask> demoDeadlines({int limit = 100, int? courseId}) {
    const open = {'backlog', 'inProgress', 'reworking'};
    final now = DateTime.now();
    final items =
        _tasks.values
            .where((t) => open.contains(t.state))
            .where((t) => t.deadline.isAfter(now))
            .where((t) => courseId == null || t.courseId == courseId)
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return items.take(limit).map(_toStudentTask).toList();
  }

  List<_DemoTask> _courseTasks(int courseId) =>
      _tasks.values.where((t) => t.courseId == courseId).toList()
        ..sort((a, b) => a.exerciseId.compareTo(b.exerciseId));

  CourseOverview? demoCourseOverview(int courseId) {
    final course = _course(courseId);
    if (course == null) return null;
    final themes = _themes.where((t) => t.courseId == courseId).toList();
    return CourseOverview(
      id: course.id,
      name: course.name,
      isArchived: course.isArchived,
      themes: [
        for (var i = 0; i < themes.length; i++)
          CourseTheme(
            id: themes[i].id,
            name: themes[i].name,
            order: i,
            state: 'published',
            longreads: [
              for (final lr in themes[i].longreads)
                Longread(
                  id: lr.id,
                  type: 'common',
                  name: lr.name,
                  state: 'published',
                  exercises: [
                    for (final task in _tasks.values.where(
                      (t) => t.longreadId == lr.id,
                    ))
                      ThemeExercise(
                        id: task.exerciseId,
                        name: task.name,
                        maxScore: task.maxScore,
                        deadline: task.deadline,
                        activity: ExerciseActivity(
                          id: task.activity.id,
                          name: task.activity.name,
                          weight: task.activity.weight,
                        ),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  _DemoLongread? _longread(int id) {
    for (final theme in _themes) {
      for (final lr in theme.longreads) {
        if (lr.id == id) return lr;
      }
    }
    return null;
  }

  LongreadMaterial _codingMaterial(_DemoTask task) {
    final isQuiz = task.type == 'questions';
    return LongreadMaterial(
      id: task.materialId,
      discriminator: isQuiz ? 'questions' : 'coding',
      attemptsLimit: isQuiz ? task.attemptsLimit : null,
      evaluationStrategy: isQuiz ? task.evaluationStrategy : null,
      name: task.name,
      viewContent: task.description,
      estimation: MaterialEstimation(
        deadline: task.deadline,
        maxScore: task.maxScore,
        activityName: task.activity.name,
        activityWeight: task.activity.weight,
      ),
      taskId: task.id,
    );
  }

  List<LongreadMaterial> demoLongreadMaterials(int longreadId) {
    final lr = _longread(longreadId);
    if (lr == null) return [];
    return [
      LongreadMaterial(
        id: longreadId * 10,
        discriminator: 'markdown',
        viewContent: lr.html,
      ),
      for (final task in _tasks.values.where((t) => t.longreadId == longreadId))
        _codingMaterial(task),
      if (longreadId == 7008)
        LongreadMaterial(
          id: 9099,
          discriminator: 'questions',
          name: 'Вопрос на занятии 4',
          estimation: MaterialEstimation(
            startDate: _nextWeekday(DateTime.wednesday, 15),
            maxScore: 0,
          ),
        ),
    ];
  }

  LongreadMaterial? demoMaterialById(int materialId) {
    for (final task in _tasks.values) {
      if (task.materialId == materialId) return _codingMaterial(task);
    }
    return null;
  }

  List<TaskEvent> demoTaskEvents(int taskId) =>
      List.of(_tasks[taskId]?.events ?? const []);

  List<TaskComment> demoTaskComments(int taskId) =>
      List.of(_tasks[taskId]?.comments ?? const []);

  TaskDetails? demoTaskDetails(int taskId) {
    final task = _tasks[taskId];
    if (task == null) return null;
    return TaskDetails(
      id: task.id,
      score: task.score,
      maxScore: task.maxScore,
      state: task.state,
      solutionUrl: task.solutionUrl,
      solutionAttachments: task.solutionAttachments,
      submitAt: task.submitAt,
      hasSolution: task.submitAt != null,
      isLateDaysEnabled: task.isLateDaysEnabled,
      lateDays: task.lateDays,
      lateDaysBalance: _lateDaysBalance,
      deadline: task.deadline,
    );
  }

  _DemoAttempt _createAttempt(_DemoTask task, DateTime startedAt) {
    final number = _attempts.values.where((a) => a.taskId == task.id).length + 1;
    final attempt = _DemoAttempt(_nextId++, task.id, number, startedAt);
    _attempts[attempt.id] = attempt;
    task
      ..currentAttemptId = attempt.id
      ..lastAttemptId = attempt.id;
    return attempt;
  }

  static bool _isCorrect(Object? expected, Object? actual) {
    if (expected == null || actual == null) return false;
    if (expected is List && actual is List) {
      return expected.length == actual.length && expected.every(actual.contains);
    }
    if (expected is String) {
      return expected.trim().toLowerCase() == actual.toString().trim().toLowerCase();
    }
    if (expected is num) {
      final value = actual is num ? actual : num.tryParse(actual.toString());
      return value == expected;
    }
    return expected == actual;
  }

  void _finishAttempt(_DemoTask task, _DemoAttempt attempt, DateTime at) {
    attempt
      ..finishedAt = at
      ..state = 'completed';
    var needsReview = false;
    var total = 0.0;
    for (final question in task.quizQuestions) {
      if (question.type == QuizQuestionType.openText) {
        needsReview = true;
        attempt.results[question.id] = null;
        continue;
      }
      final score = _isCorrect(task.correctAnswers[question.id], attempt.answers[question.id])
          ? question.maxScore ?? 0
          : 0.0;
      attempt.results[question.id] = score;
      total += score;
    }
    task
      ..currentAttemptId = null
      ..submitAt = at
      ..state = needsReview ? 'review' : 'evaluated'
      ..score = needsReview ? null : total;
    _event(task, 'taskCompleted', at);
  }

  void _expireAttempt(_DemoTask task) {
    final attempt = _attempts[task.currentAttemptId];
    final timer = task.timer;
    if (attempt == null || timer == null) return;
    final end = attempt.startedAt.add(timer);
    if (DateTime.now().isAfter(end)) _finishAttempt(task, attempt, end);
  }

  QuizTask? demoQuizTask(int taskId) {
    final task = _tasks[taskId];
    if (task == null || !task.isQuiz) return null;
    _expireAttempt(task);
    return QuizTask(
      id: task.id,
      state: task.state,
      score: task.score,
      maxScore: task.maxScore.toDouble(),
      deadline: task.deadline,
      submitAt: task.submitAt,
      quizId: task.exerciseId,
      quizSessionId: task.state == 'backlog' ? null : task.quizSessionId,
      currentAttemptId: task.currentAttemptId,
      evaluatedAttemptId: task.state == 'evaluated' ? task.lastAttemptId : null,
      lastAttemptId: task.lastAttemptId,
      timer: task.timer,
      attemptsLimit: task.attemptsLimit,
      evaluationStrategy: task.evaluationStrategy,
    );
  }

  List<QuizPlayerQuestion>? demoQuizQuestions(int quizId) {
    for (final task in _tasks.values) {
      if (task.isQuiz && task.exerciseId == quizId) return task.quizQuestions;
    }
    return null;
  }

  QuizAttempt? demoQuizAttempt(int attemptId) {
    final attempt = _attempts[attemptId];
    if (attempt == null) return null;
    final task = _tasks[attempt.taskId]!;
    final evaluated = task.state == 'evaluated';
    return QuizAttempt(
      id: attempt.id,
      number: attempt.number,
      state: attempt.state,
      startedAt: attempt.startedAt,
      finishedAt: attempt.finishedAt,
      score: evaluated ? task.score : null,
      answers: Map.of(attempt.answers),
      results: attempt.finishedAt == null ? const {} : Map.of(attempt.results),
    );
  }

  QuizActionResult startQuizAttempt(int sessionId) {
    final task = _tasks[sessionId - 50000];
    if (task == null || !task.isQuiz) return const QuizActionResult(false);
    if (task.currentAttemptId != null) {
      return const QuizActionResult(false, 'hasActiveAttempt');
    }
    final used = _attempts.values.where((a) => a.taskId == task.id).length;
    if (used >= task.attemptsLimit) {
      return const QuizActionResult(false, 'attemptsLimitReached');
    }
    _createAttempt(task, DateTime.now());
    return const QuizActionResult(true);
  }

  QuizActionResult submitQuizAnswer(int attemptId, int questionId, Object? answer) {
    final attempt = _attempts[attemptId];
    if (attempt == null || attempt.finishedAt != null) {
      return const QuizActionResult(false, 'invalidState');
    }
    attempt.answers[questionId] = answer;
    return const QuizActionResult(true);
  }

  QuizActionResult completeQuizAttempt(int attemptId) {
    final attempt = _attempts[attemptId];
    if (attempt == null || attempt.finishedAt != null) {
      return const QuizActionResult(false, 'invalidState');
    }
    _finishAttempt(_tasks[attempt.taskId]!, attempt, DateTime.now());
    return const QuizActionResult(true);
  }

  String? createTaskComment(
    int taskId,
    String content,
    List<Map<String, dynamic>> attachments,
  ) {
    final task = _tasks[taskId];
    if (task == null) return null;
    final comment = _comment(
      content,
      DateTime.now(),
      fromStudent: true,
      attachments: attachments.map(MaterialAttachment.fromJson).toList(),
    );
    task.comments.add(comment);
    return comment.id;
  }

  bool startTask(int taskId) {
    final task = _tasks[taskId];
    if (task == null) return false;
    if (task.state == 'backlog') {
      task.state = 'inProgress';
      _event(task, 'taskStarted', DateTime.now());
      if (task.isQuiz) _createAttempt(task, DateTime.now());
    }
    return true;
  }

  bool submitTaskSolution(
    int taskId,
    String? solutionUrl,
    List<Map<String, dynamic>> attachments,
  ) {
    final task = _tasks[taskId];
    if (task == null) return false;
    final now = DateTime.now();
    if (task.state == 'backlog') {
      _event(task, 'taskStarted', now);
    }
    task
      ..state = 'review'
      ..submitAt = now
      ..solutionUrl = solutionUrl
      ..solutionAttachments = attachments
          .map(MaterialAttachment.fromJson)
          .toList();
    _event(task, 'solutionAttached', now);
    _event(task, 'taskCompleted', now);
    return true;
  }

  bool prolongLateDays(int taskId, int days) {
    final task = _tasks[taskId];
    if (task == null || !task.isLateDaysEnabled) return false;
    if (days <= 0 || days > _lateDaysBalance) return false;
    task.lateDays += days;
    _lateDaysBalance -= days;
    _event(task, 'taskLateDaysProlong', DateTime.now(), lateDays: days);
    return true;
  }

  bool cancelLateDays(int taskId) {
    final task = _tasks[taskId];
    if (task == null || task.lateDays == 0) return false;
    _lateDaysBalance += task.lateDays;
    task.lateDays = 0;
    _event(task, 'taskLateDaysCancelled', DateTime.now());
    return true;
  }

  StudentPerformanceResponse demoPerformance() {
    return StudentPerformanceResponse(
      courses: [
        for (final course in _courses.where((c) => !c.isArchived))
          StudentPerformanceCourse(
            id: course.id,
            name: course.name,
            total: (_progress(course.id).earnedScore * 10).round(),
          ),
      ],
    );
  }

  CourseExercisesResponse? demoCourseExercises(int courseId) {
    final course = _course(courseId);
    if (course == null) return null;
    final tasks = _courseTasks(courseId);
    return CourseExercisesResponse(
      id: course.id,
      name: course.name,
      isArchived: course.isArchived,
      exercises: [
        for (final task in tasks)
          CourseExercise(
            id: task.exerciseId,
            name: task.name,
            type: task.type,
            activity: CourseExerciseActivity(
              id: task.activity.id,
              name: task.activity.name,
              weight: task.activity.weight,
              maxExercisesCount: _activityCount(tasks, task.activity.id),
            ),
            theme: CourseExerciseTheme(
              id: task.themeId,
              name: _themes.firstWhere((t) => t.id == task.themeId).name,
            ),
          ),
      ],
    );
  }

  int _activityCount(List<_DemoTask> tasks, int activityId) =>
      tasks.where((t) => t.activity.id == activityId).length;

  TaskScoreActivity _scoreActivity(
    List<_DemoTask> tasks,
    _DemoActivity activity,
  ) {
    return TaskScoreActivity(
      id: activity.id,
      name: activity.name,
      weight: activity.weight,
      maxExercisesCount: _activityCount(tasks, activity.id),
    );
  }

  CourseStudentPerformanceResponse demoCourseStudentPerformance(int courseId) {
    final tasks = _courseTasks(courseId);
    return CourseStudentPerformanceResponse(
      tasks: [
        for (final task in tasks)
          TaskScore(
            id: task.id,
            state: task.state,
            score: task.score ?? 0,
            exerciseId: task.exerciseId,
            maxScore: task.maxScore,
            activity: _scoreActivity(tasks, task.activity),
          ),
      ],
    );
  }

  List<ActivityPerformance> demoActivitiesPerformance(int courseId) {
    final tasks = _courseTasks(courseId);
    final activities = <int, _DemoActivity>{
      for (final task in tasks) task.activity.id: task.activity,
    };
    return [
      for (final activity in activities.values)
        () {
          final scoped = tasks
              .where((t) => t.activity.id == activity.id)
              .toList();
          final sum = scoped.fold<double>(0, (acc, t) => acc + (t.score ?? 0));
          final average = scoped.isEmpty ? 0.0 : sum / scoped.length;
          return ActivityPerformance(
            activity: _scoreActivity(tasks, activity),
            total: average * activity.weight,
            average: average,
          );
        }(),
    ];
  }

  CourseProgress _progress(int courseId) {
    final tasks = _courseTasks(courseId);
    var earned = 0.0;
    var left = 0.0;
    for (final task in tasks) {
      final count = _activityCount(tasks, task.activity.id);
      final share = 10 * task.activity.weight / count;
      if (task.state == 'evaluated') {
        earned += share * (task.score ?? 0) / task.maxScore;
      } else if (task.state != 'failed') {
        left += share;
      }
    }
    return CourseProgress(
      earnedScore: earned,
      leftToEarnScore: left,
      maxScore: 10,
    );
  }

  CourseProgress? demoCourseProgress(int courseId) =>
      _course(courseId) == null ? null : _progress(courseId);

  GradebookResponse demoGradebook() {
    return GradebookResponse(
      semesters: [
        GradebookSemester(
          year: 2023,
          semesterNumber: 1,
          grades: [
            GradebookGrade(
              subject: 'Математический анализ',
              grade: 5,
              normalizedGrade: 'excellent',
              assessmentType: 'exam',
              subjectType: 'required',
            ),
            GradebookGrade(
              subject: 'Программирование на Python',
              grade: 4,
              normalizedGrade: 'good',
              assessmentType: 'difCredit',
              subjectType: 'required',
            ),
            GradebookGrade(
              subject: 'Английский язык',
              grade: null,
              normalizedGrade: 'passed',
              assessmentType: 'credit',
              subjectType: 'required',
            ),
            GradebookGrade(
              subject: 'Шахматы',
              grade: null,
              normalizedGrade: 'passed',
              assessmentType: 'credit',
              subjectType: 'elective',
            ),
          ],
        ),
        GradebookSemester(
          year: 2024,
          semesterNumber: 2,
          grades: [
            GradebookGrade(
              subject: 'Линейная алгебра',
              grade: 4,
              normalizedGrade: 'good',
              assessmentType: 'exam',
              subjectType: 'required',
            ),
            GradebookGrade(
              subject: 'Алгоритмы и структуры данных',
              grade: 5,
              normalizedGrade: 'excellent',
              assessmentType: 'difCredit',
              subjectType: 'required',
            ),
          ],
        ),
      ],
    );
  }

  List<NotificationItem> demoNotifications(int category) {
    final now = DateTime.now();
    if (category != 1) {
      return [
        NotificationItem(
          id: 4101,
          createdAt: now.subtract(const Duration(hours: 5)),
          category: 'other',
          icon: 'event',
          title: 'Хакатон в кампусе',
          description:
              'В субботу пройдёт студенческий хакатон. Регистрация открыта до пятницы.',
          link: null,
        ),
        NotificationItem(
          id: 4102,
          createdAt: now.subtract(const Duration(days: 4)),
          category: 'other',
          icon: 'info',
          title: 'Обновление расписания',
          description: 'В расписании на следующую неделю появились изменения.',
          link: null,
        ),
      ];
    }
    return [
      NotificationItem(
        id: 4001,
        createdAt: now.subtract(const Duration(hours: 2)),
        category: 'task',
        icon: 'assignment',
        title: 'Новое задание',
        description:
            'Добавлено задание «Рекурсивные функции» по курсу «Основы программирования».',
        link: null,
      ),
      NotificationItem(
        id: 4002,
        createdAt: now.subtract(const Duration(days: 1)),
        category: 'task',
        icon: 'grade',
        title: 'Задание отправлено на доработку',
        description:
            'Задание «Визуализация данных» вернули на доработку. Посмотрите комментарий.',
        link: null,
      ),
      NotificationItem(
        id: 4003,
        createdAt: now.subtract(const Duration(days: 6)),
        category: 'task',
        icon: 'grade',
        title: 'Задание оценено',
        description: 'Ваше задание «Базис и размерность» получило оценку 8/10.',
        link: null,
      ),
      NotificationItem(
        id: 4004,
        createdAt: now.subtract(const Duration(days: 10)),
        category: 'course',
        icon: 'school',
        title: 'Новый курс',
        description: 'Вы добавлены в курс «Основы Data Science».',
        link: null,
      ),
    ];
  }

  static DateTime _nextWeekday(int weekday, int hour) {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day, hour);
    while (day.weekday != weekday || !day.isAfter(now)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static DateTime _at(DateTime day, String time) {
    final parts = time.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String _slotTitle(_DemoSlot slot) {
    final course = _courses.firstWhere((c) => c.id == slot.courseId);
    return '${slot.type == 'lecture' ? 'Лекция' : 'Семинар'}: ${course.cleanName}';
  }

  static DateTime get _semesterStart {
    final now = DateTime.now();
    final year = now.month >= 9 ? now.year : now.year - 1;
    final start = DateTime(year, 9, 1);
    final today = DateTime(now.year, now.month, now.day);
    final fallback = today.subtract(const Duration(days: 35));
    return start.isAfter(fallback) ? fallback : start;
  }

  static bool _wasMissed(DateTime day, int courseId) =>
      (day.day + courseId) % 6 == 0;

  List<CalendarEvent> demoCalendarEvents(DateTime day) {
    return [
      for (final slot in _slots.where((s) => s.weekday == day.weekday))
        CalendarEvent(
          start: _at(day, slot.start),
          end: _at(day, slot.end),
          summary: '${_slotTitle(slot)} ${slot.room}',
          link: slot.format == 'online' ? 'https://ktalk.ru/demo' : null,
        ),
    ];
  }

  List<ExamItem> demoExams(String courseTitle) {
    final match = _courses.where(
      (c) => !c.isArchived && c.cleanName == courseTitle,
    );
    if (match.isEmpty) return [];
    final courseId = match.first.id;
    final now = DateTime.now();
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 14 + courseId % 7));
    final week = date.difference(_semesterStart).inDays ~/ 7 + 1;
    return [
      ExamItem(
        name: 'Контрольная работа',
        rawDate: '${_two(date.day)}.${_two(date.month)}',
        date: date,
        weekNumber: week,
      ),
    ];
  }

  List<_DateSlot> _pastSlots(int courseId) {
    final now = DateTime.now();
    final result = <_DateSlot>[];
    var day = _semesterStart;
    while (!day.isAfter(now)) {
      for (final slot in _slots.where(
        (s) => s.courseId == courseId && s.weekday == day.weekday,
      )) {
        if (_at(day, slot.end).isBefore(now)) result.add(_DateSlot(day, slot));
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  List<AttendanceCourse> demoAttendanceCourses({bool archived = false}) {
    if (archived) return [];
    return [
      for (final course in _courses.where((c) => !c.isArchived))
        () {
          final past = _pastSlots(course.id);
          final attended = past
              .where((p) => !_wasMissed(p.day, course.id))
              .length;
          return AttendanceCourse(
            courseId: course.id,
            courseName: course.name,
            studentStatus: course.id == 1004 ? 'elective' : 'required',
            isVisibleForStudents: course.id != 1004,
            stats: AttendanceStats(
              percent: past.isEmpty ? 0 : attended * 100 / past.length,
              attendedCount: attended,
              enrolledCount: past.length,
            ),
          );
        }(),
    ];
  }

  String _eventId(int courseId, DateTime day, _DemoSlot slot) =>
      'demo-$courseId-${_date(day)}-${slot.start.replaceAll(':', '')}';

  List<AttendanceEvent> demoCourseEventsByDate(int courseId, String date) {
    final day = DateTime.tryParse(date);
    if (day == null) return [];
    final slots = _slots.where(
      (s) => s.courseId == courseId && s.weekday == day.weekday,
    );
    final course = _course(courseId);
    return [
      for (final slot in slots)
        AttendanceEvent(
          eventId: _eventId(courseId, day, slot),
          isParticipant: true,
          actualDate: _date(day),
          startTime: '${slot.start}:00',
          endTime: '${slot.end}:00',
          title: course?.cleanName ?? '',
          eventType: slot.type,
          format: slot.format,
          rowNumber: day.difference(_semesterStart).inDays ~/ 7 + 1,
          locationTitle: slot.format == 'offline' ? slot.room : null,
          hosts: [AttendanceHost(email: slot.host.email, name: slot.host.name)],
        ),
    ];
  }

  Set<String> demoAttendedEventIds(int courseId, String date) {
    final day = DateTime.tryParse(date);
    if (day == null || _wasMissed(day, courseId)) return {};
    final now = DateTime.now();
    return {
      for (final slot in _slots.where(
        (s) => s.courseId == courseId && s.weekday == day.weekday,
      ))
        if (_at(day, slot.end).isBefore(now)) _eventId(courseId, day, slot),
    };
  }

  List<RecordingHost> demoRecordingHosts(int courseId) {
    final hosts = <String, _DemoHost>{
      for (final slot in _slots.where((s) => s.courseId == courseId))
        slot.host.email: slot.host,
    };
    return [
      for (final host in hosts.values)
        RecordingHost(id: host.id, name: host.name, email: host.email),
    ];
  }

  RecordingEventsPage demoRecordingEvents({
    required int courseId,
    int offset = 0,
    int limit = 100,
    Iterable<String> eventTypes = const [],
    Iterable<String> hostEmails = const [],
  }) {
    final types = eventTypes.toSet();
    final emails = hostEmails.toSet();
    final course = _course(courseId);
    final all = _pastSlots(courseId)
        .where((p) => types.isEmpty || types.contains(p.slot.type))
        .where((p) => emails.isEmpty || emails.contains(p.slot.host.email))
        .toList()
        .reversed
        .map(
          (p) => RecordingEvent(
            id: _eventId(courseId, p.day, p.slot),
            title:
                '${p.slot.type == 'lecture' ? 'Лекция' : 'Семинар'}. '
                '${course?.cleanName ?? ''}',
            type: p.slot.type,
            hosts: [
              RecordingHost(
                id: p.slot.host.id,
                name: p.slot.host.name,
                email: p.slot.host.email,
              ),
            ],
            actualDate: _date(p.day),
            startTime: '${p.slot.start}:00',
            endTime: '${p.slot.end}:00',
          ),
        )
        .toList();
    return RecordingEventsPage(
      items: all.skip(offset).take(limit).toList(),
      totalCount: all.length,
    );
  }

  List<EventRecording> demoEventRecordings(String eventId) {
    final seed = eventId.codeUnits.fold<int>(0, (acc, c) => acc + c);
    final random = Random(seed);
    return [
      EventRecording(url: _recordingUrl, duration: 4800 + random.nextInt(900)),
    ];
  }

  static const _gitHtml = '''
<h2>Зачем нужен Git</h2>
<p>Git — распределённая система контроля версий. Она хранит историю изменений проекта и позволяет нескольким людям работать над кодом одновременно.</p>
<h3>Базовые команды</h3>
<ul>
<li><code>git init</code> — создать репозиторий</li>
<li><code>git add</code> — добавить изменения в индекс</li>
<li><code>git commit</code> — зафиксировать изменения</li>
<li><code>git push</code> — отправить коммиты на сервер</li>
</ul>
<pre><code>git checkout -b feature/readme
git commit -m "Add README"
git push origin feature/readme</code></pre>
''';

  static const _sortHtml = '''
<h2>Сортировка слиянием</h2>
<p>Алгоритм делит массив пополам, рекурсивно сортирует каждую половину и сливает результаты. Сложность — <b>O(n log n)</b> в любом случае.</p>
<pre><code>def merge_sort(items):
    if len(items) &lt;= 1:
        return items
    mid = len(items) // 2
    return merge(merge_sort(items[:mid]), merge_sort(items[mid:]))</code></pre>
<p>Подумайте, почему сортировка слиянием устойчива, а быстрая сортировка — нет.</p>
''';

  static const _recursionHtml = '''
<h2>Рекурсия</h2>
<p>Рекурсивная функция вызывает саму себя для решения меньшей подзадачи. У каждой рекурсии должен быть <b>базовый случай</b>, иначе она никогда не закончится.</p>
<pre><code>def factorial(n):
    return 1 if n == 0 else n * factorial(n - 1)</code></pre>
''';

  static const _matrixHtml = '''
<h2>Определитель матрицы</h2>
<p>Определитель квадратной матрицы показывает, во сколько раз линейное преобразование меняет объём. Если определитель равен нулю, матрица вырождена.</p>
<p>Для матрицы 2×2: <code>det A = ad − bc</code>.</p>
<ul>
<li>Перестановка двух строк меняет знак определителя</li>
<li>Определитель произведения равен произведению определителей</li>
</ul>
''';

  static const _basisHtml = '''
<h2>Базис</h2>
<p>Базис — это линейно независимая система векторов, через которую выражается любой вектор пространства. Число векторов в базисе называется <b>размерностью</b>.</p>
''';

  static const _pandasHtml = '''
<h2>Знакомство с pandas</h2>
<p>pandas — библиотека для работы с табличными данными. Основные структуры — <code>Series</code> и <code>DataFrame</code>.</p>
<pre><code>import pandas as pd
df = pd.read_csv("taxi.csv")
df.describe()</code></pre>
''';

  static const _vizHtml = '''
<h2>Визуализация данных</h2>
<p>Хороший график отвечает на один вопрос. Всегда подписывайте оси, указывайте единицы измерения и добавляйте легенду, если на графике несколько серий.</p>
''';

  static const _speechHtml = '''
<h2>Как подготовить выступление</h2>
<ol>
<li>Сформулируйте одну главную мысль</li>
<li>Постройте структуру: вступление, три аргумента, вывод</li>
<li>Отрепетируйте выступление вслух хотя бы дважды</li>
</ol>
''';

  static const _bigOHtml = '''
<h2>O-нотация</h2>
<p>O-нотация описывает, как растёт время работы алгоритма с увеличением размера входных данных.</p>
''';
}

class _DateSlot {
  final DateTime day;
  final _DemoSlot slot;

  const _DateSlot(this.day, this.slot);
}

final DemoService demoService = DemoService();
