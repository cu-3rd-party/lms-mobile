class StudentProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String middleName;
  final String birthdate;
  final String? birthPlace;
  final String? telegram;
  final String timeLogin;
  final String inn;
  final String snils;
  final int course;
  final String gender;
  final String enrollmentPhase;
  final String educationLevel;
  final List<EmailInfo> emails;
  final List<PhoneInfo> phones;

  StudentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.birthdate,
    this.birthPlace,
    this.telegram,
    required this.timeLogin,
    required this.inn,
    required this.snils,
    required this.course,
    required this.gender,
    required this.enrollmentPhase,
    required this.educationLevel,
    required this.emails,
    required this.phones,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      middleName: json['middleName'] ?? '',
      birthdate: json['birthdate'] ?? '',
      birthPlace: json['birthPlace'],
      telegram: json['telegram'],
      timeLogin: json['timeLogin'] ?? '',
      inn: json['inn'] ?? '',
      snils: json['snils'] ?? '',
      course: json['course'] ?? 0,
      gender: json['gender'] ?? '',
      enrollmentPhase: json['enrollmentPhase'] ?? '',
      educationLevel: json['educationLevel'] ?? '',
      emails: (json['emails'] as List?)
              ?.map((e) => EmailInfo.fromJson(e))
              .toList() ??
          [],
      phones: (json['phones'] as List?)
              ?.map((e) => PhoneInfo.fromJson(e))
              .toList() ??
          [],
    );
  }

  String get fullName => '$lastName $firstName $middleName';

  String get maskedInn => _maskMiddle(inn, 3, 2);
  String get maskedSnils => _maskMiddle(snils, 3, 2);
  String get maskedBirthdate => _maskMiddle(birthdate, 4, 0);
  String get maskedBirthPlace => birthPlace != null ? _maskMiddle(birthPlace!, 5, 3) : '';

  String? get universityEmail {
    final edu = emails.firstWhere(
      (e) => e.value.toLowerCase().endsWith('@edu.centraluniversity.ru'),
      orElse: () => EmailInfo(value: '', type: ''),
    );
    if (edu.value.isNotEmpty) return edu.value;
    final cu = emails.firstWhere(
      (e) => e.value.toLowerCase().endsWith('@centraluniversity.ru'),
      orElse: () => EmailInfo(value: '', type: ''),
    );
    if (cu.value.isNotEmpty) return cu.value;
    final typed = emails.firstWhere(
      (e) => e.type.toLowerCase().contains('university'),
      orElse: () => EmailInfo(value: '', type: ''),
    );
    if (typed.value.isNotEmpty) return typed.value;
    return emails.isNotEmpty ? emails.first.value : null;
  }

  static String _maskMiddle(String value, int showStart, int showEnd) {
    if (value.length <= showStart + showEnd) return value;
    final start = value.substring(0, showStart);
    final end = showEnd > 0 ? value.substring(value.length - showEnd) : '';
    final middle = '*' * (value.length - showStart - showEnd);
    return '$start$middle$end';
  }
}

class EmailInfo {
  final String value;
  final String type;

  EmailInfo({required this.value, required this.type});

  factory EmailInfo.fromJson(Map<String, dynamic> json) {
    return EmailInfo(
      value: json['value'] ?? '',
      type: json['type'] ?? '',
    );
  }

  String get masked {
    final parts = value.split('@');
    if (parts.length != 2) return value;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return value;
    return '${name.substring(0, 3)}${'*' * (name.length - 3)}@$domain';
  }
}

class PhoneInfo {
  final String value;
  final String type;

  PhoneInfo({required this.value, required this.type});

  factory PhoneInfo.fromJson(Map<String, dynamic> json) {
    return PhoneInfo(
      value: json['value'] ?? '',
      type: json['type'] ?? '',
    );
  }

  String get masked {
    if (value.length < 7) return value;
    return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
  }
}
