class NotificationItem {
  final int id;
  final DateTime createdAt;
  final String category;
  final String icon;
  final String title;
  final String description;
  final NotificationLink? link;

  NotificationItem({
    required this.id,
    required this.createdAt,
    required this.category,
    required this.icon,
    required this.title,
    required this.description,
    required this.link,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      category: json['category'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      link: json['link'] == null
          ? null
          : NotificationLink.fromJson(json['link'] as Map<String, dynamic>),
    );
  }
}

class NotificationLink {
  final String uri;
  final String label;
  final String target;

  NotificationLink({
    required this.uri,
    required this.label,
    required this.target,
  });

  factory NotificationLink.fromJson(Map<String, dynamic> json) {
    return NotificationLink(
      uri: json['uri'] as String? ?? '',
      label: json['label'] as String? ?? '',
      target: json['target'] as String? ?? '',
    );
  }
}
