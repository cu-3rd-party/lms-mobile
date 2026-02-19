import 'package:flutter/material.dart';

class Course {
  final int id;
  final String name;
  final String state;
  final String category;
  final String categoryCover;
  final bool isArchived;

  Course({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    required this.categoryCover,
    required this.isArchived,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      category: json['category'] ?? 'general',
      categoryCover: json['categoryCover'] ?? '',
      isArchived: json['isArchived'] ?? false,
    );
  }

  String get cleanName => name.replaceAll(RegExp(r'^[\u{1F300}-\u{1F9FF}]\s*', unicode: true), '');

  Color get categoryColor {
    switch (category) {
      case 'mathematics':
        return const Color(0xFF2196F3);
      case 'development':
        return const Color(0xFF4CAF50);
      case 'stem':
        return const Color(0xFF9C27B0);
      case 'general':
        return const Color(0xFFFF9800);
      case 'business':
        return const Color(0xFFE91E63);
      case 'softSkills':
        return const Color(0xFF00BCD4);
      case 'withoutCategory':
      default:
        return const Color(0xFF607D8B);
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'mathematics':
        return Icons.functions;
      case 'development':
        return Icons.code;
      case 'stem':
        return Icons.science;
      case 'general':
        return Icons.school;
      case 'business':
        return Icons.business_center;
      case 'softSkills':
        return Icons.people;
      case 'withoutCategory':
      default:
        return Icons.category;
    }
  }
}
