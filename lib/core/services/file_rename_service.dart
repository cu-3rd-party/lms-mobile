import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FileRenameRule {
  final int courseId;
  final String? activityType;
  final String fileExtension;
  final String targetName;

  FileRenameRule({
    required this.courseId,
    this.activityType,
    required this.fileExtension,
    required this.targetName,
  });

  String get key => '$courseId|${activityType ?? '*'}|$fileExtension';

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'activityType': activityType,
        'fileExtension': fileExtension,
        'targetName': targetName,
      };

  factory FileRenameRule.fromJson(Map<String, dynamic> json) {
    return FileRenameRule(
      courseId: json['courseId'] ?? 0,
      activityType: json['activityType'],
      fileExtension: json['fileExtension'] ?? '',
      targetName: json['targetName'] ?? '',
    );
  }
}

class FileRenameService {
  static const _storageKey = 'file_rename_rules';
  static FileRenameService? _instance;

  final Map<String, FileRenameRule> _rules = {};

  FileRenameService._();

  static FileRenameService get instance {
    _instance ??= FileRenameService._();
    return _instance!;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null) return;

    try {
      final list = jsonDecode(data) as List;
      _rules.clear();
      for (final item in list) {
        final rule = FileRenameRule.fromJson(item);
        _rules[rule.key] = rule;
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_rules.values.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  List<FileRenameRule> getRulesForCourse(int courseId) {
    return _rules.values.where((r) => r.courseId == courseId).toList();
  }

  List<FileRenameRule> getAllRules() {
    return _rules.values.toList();
  }

  FileRenameRule? findRule({
    required int courseId,
    String? activityType,
    required String fileExtension,
  }) {
    final ext = fileExtension.toLowerCase().replaceAll('.', '');

    // Try exact match first
    final exactKey = '$courseId|${activityType ?? '*'}|$ext';
    if (_rules.containsKey(exactKey)) {
      return _rules[exactKey];
    }

    // Try with wildcard activity
    final wildcardKey = '$courseId|*|$ext';
    if (_rules.containsKey(wildcardKey)) {
      return _rules[wildcardKey];
    }

    return null;
  }

  Future<void> addRule(FileRenameRule rule) async {
    _rules[rule.key] = rule;
    await _save();
  }

  Future<void> removeRule(String key) async {
    _rules.remove(key);
    await _save();
  }

  Future<void> clearRulesForCourse(int courseId) async {
    _rules.removeWhere((key, rule) => rule.courseId == courseId);
    await _save();
  }
}
