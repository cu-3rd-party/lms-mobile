class StudentLmsProfile {
  final String id;
  final String lastName;
  final String firstName;
  final String? middleName;
  final String universityEmail;
  final String timeAccount;
  final int studyStartYear;
  final String studyLevel;
  final int lateDaysBalance;

  StudentLmsProfile({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName,
    required this.universityEmail,
    required this.timeAccount,
    required this.studyStartYear,
    required this.studyLevel,
    required this.lateDaysBalance,
  });

  factory StudentLmsProfile.fromJson(Map<String, dynamic> json) {
    return StudentLmsProfile(
      id: json['id'] ?? '',
      lastName: json['lastName'] ?? '',
      firstName: json['firstName'] ?? '',
      middleName: json['middleName'],
      universityEmail: json['universityEmail'] ?? '',
      timeAccount: json['timeAccount'] ?? '',
      studyStartYear: json['studyStartYear'] ?? 0,
      studyLevel: json['studyLevel'] ?? '',
      lateDaysBalance: json['lateDaysBalance'] ?? 0,
    );
  }
}
