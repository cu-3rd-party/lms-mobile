import 'dart:typed_data';

import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/notification_item.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_performance.dart';
import 'package:cumobile/data/models/student_profile.dart';
import 'package:cumobile/data/models/student_task.dart';

class DemoService {
  bool _isDemoMode = false;

  bool get isDemoMode => _isDemoMode;

  void enableDemo() {
    _isDemoMode = true;
  }

  void exitDemo() {
    _isDemoMode = false;
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
        EmailInfo(value: 'demo.student@edu.centraluniversity.ru', type: 'university'),
        EmailInfo(value: 'demo@example.com', type: 'personal'),
      ],
      phones: [
        PhoneInfo(value: '79001234567', type: 'mobile'),
      ],
    );
  }

  Uint8List? demoAvatar() => null;

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
      lateDaysBalance: 5,
    );
  }

  List<Course> demoCourses() {
    return [
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
  }

  List<StudentTask> demoTasks() {
    final now = DateTime.now();
    return [
      StudentTask(
        id: 2001,
        state: 'inProgress',
        score: null,
        deadline: now.add(const Duration(days: 3)),
        submitAt: null,
        exercise: TaskExercise(
          id: 3001,
          name: 'Алгоритм сортировки',
          type: 'coding',
          maxScore: 10,
        ),
        course: TaskCourse(id: 1001, name: '💻 Основы программирования', isArchived: false),
        isLateDaysEnabled: true,
        lateDays: 0,
      ),
      StudentTask(
        id: 2002,
        state: 'backlog',
        score: null,
        deadline: now.add(const Duration(days: 7)),
        submitAt: null,
        exercise: TaskExercise(
          id: 3002,
          name: 'Матрицы и определители',
          type: 'essay',
          maxScore: 10,
        ),
        course: TaskCourse(id: 1002, name: '📐 Линейная алгебра', isArchived: false),
        isLateDaysEnabled: false,
        lateDays: 0,
      ),
      StudentTask(
        id: 2003,
        state: 'review',
        score: null,
        deadline: now.subtract(const Duration(days: 1)),
        submitAt: now.subtract(const Duration(days: 2)),
        exercise: TaskExercise(
          id: 3003,
          name: 'Анализ датасета',
          type: 'coding',
          maxScore: 10,
        ),
        course: TaskCourse(id: 1003, name: '🔬 Основы Data Science', isArchived: false),
        isLateDaysEnabled: false,
        lateDays: 0,
      ),
      StudentTask(
        id: 2004,
        state: 'evaluated',
        score: 9.0,
        deadline: now.subtract(const Duration(days: 10)),
        submitAt: now.subtract(const Duration(days: 12)),
        exercise: TaskExercise(
          id: 3004,
          name: 'Введение в Git',
          type: 'coding',
          maxScore: 10,
        ),
        course: TaskCourse(id: 1001, name: '💻 Основы программирования', isArchived: false),
        isLateDaysEnabled: false,
        lateDays: 0,
      ),
      StudentTask(
        id: 2005,
        state: 'failed',
        score: 0.0,
        deadline: now.subtract(const Duration(days: 5)),
        submitAt: null,
        exercise: TaskExercise(
          id: 3005,
          name: 'Публичное выступление',
          type: 'essay',
          maxScore: 10,
        ),
        course: TaskCourse(id: 1004, name: '🤝 Командная работа', isArchived: false),
        isLateDaysEnabled: true,
        lateDays: 2,
      ),
    ];
  }

  StudentPerformanceResponse demoPerformance() {
    return StudentPerformanceResponse(
      courses: [
        StudentPerformanceCourse(id: 1001, name: '💻 Основы программирования', total: 28),
        StudentPerformanceCourse(id: 1002, name: '📐 Линейная алгебра', total: 15),
        StudentPerformanceCourse(id: 1003, name: '🔬 Основы Data Science', total: 22),
        StudentPerformanceCourse(id: 1004, name: '🤝 Командная работа', total: 10),
      ],
    );
  }

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

  List<NotificationItem> demoNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 4001,
        createdAt: now.subtract(const Duration(hours: 2)),
        category: 'task',
        icon: 'assignment',
        title: 'Новое задание',
        description: 'Добавлено задание «Алгоритм сортировки» по курсу «Основы программирования».',
        link: null,
      ),
      NotificationItem(
        id: 4002,
        createdAt: now.subtract(const Duration(days: 1)),
        category: 'task',
        icon: 'grade',
        title: 'Задание оценено',
        description: 'Ваше задание «Введение в Git» получило оценку 9/10.',
        link: null,
      ),
      NotificationItem(
        id: 4003,
        createdAt: now.subtract(const Duration(days: 3)),
        category: 'course',
        icon: 'school',
        title: 'Новый курс',
        description: 'Вы добавлены в курс «Основы Data Science».',
        link: null,
      ),
    ];
  }
}

final DemoService demoService = DemoService();
