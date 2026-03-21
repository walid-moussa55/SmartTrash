// lib/app_notification_model.dart

class AppNotification {
  final String key;
  final String title;
  final String body;
  final DateTime sentTime;
  final Map<String, dynamic> data;

  AppNotification({
    required this.key,
    required this.title,
    required this.body,
    required this.sentTime,
    required this.data,
  });

  factory AppNotification.fromMap(String key, Map<dynamic, dynamic> value) {
    return AppNotification(
      key: key,
      title: value['title'] ?? 'No Title',
      body: value['body'] ?? 'No Body',
      sentTime: DateTime.fromMillisecondsSinceEpoch(
          value['sentTime'] ?? DateTime.now().millisecondsSinceEpoch),
      data: Map<String, dynamic>.from(value['data'] ?? {}),
    );
  }
}
