import 'package:cumobile/data/models/longread_material.dart';

class TaskComment {
  final String id;
  final String content;
  final CommentSender sender;
  final DateTime? createdAt;
  final List<MaterialAttachment> attachments;

  TaskComment({
    required this.id,
    required this.content,
    required this.sender,
    required this.createdAt,
    required this.attachments,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return TaskComment(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      sender: CommentSender.fromJson(
        sender is Map<String, dynamic> ? sender : const <String, dynamic>{},
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      attachments: (json['attachments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MaterialAttachment.fromJson)
              .toList() ??
          [],
    );
  }
}

class CommentSender {
  final String id;
  final String email;
  final String name;

  CommentSender({
    required this.id,
    required this.email,
    required this.name,
  });

  factory CommentSender.fromJson(Map<String, dynamic> json) {
    return CommentSender(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
