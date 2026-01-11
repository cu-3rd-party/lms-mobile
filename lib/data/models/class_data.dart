import 'package:flutter/material.dart';

class ClassData {
  final String startTime;
  final String endTime;
  final String room;
  final String type;
  final String title;
  final String? professor;
  final String? link;
  final String? badge;
  final Color? badgeColor;

  ClassData({
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.type,
    required this.title,
    this.professor,
    this.link,
    this.badge,
    this.badgeColor,
  });
}
