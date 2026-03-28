class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
