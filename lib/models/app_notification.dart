import 'package:cloud_firestore/cloud_firestore.dart';

/// A users/{uid}/notifications/{id} entry — the in-app counterpart to each
/// push notification functions/index.js sends (see that file's notifyUser),
/// read by the notification bell in the app's header.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? groupId;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.groupId,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: (map['type'] as String?) ?? '',
      groupId: map['groupId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: (map['read'] as bool?) ?? false,
    );
  }
}
