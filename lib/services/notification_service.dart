import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_notification.dart';

/// FR 2.6 (Notifications & Reminders) — client side: requests permission,
/// registers this device's FCM token under users/{uid}/fcmTokens/{token} so
/// the Cloud Functions in functions/ (due-date reminders, missed-payment
/// alerts, pending-approval pushes, entry/approve/reject/builder-payment
/// events) can target this user, surfaces foreground messages via
/// [onForegroundMessage], and reads the same events back out of the
/// users/{uid}/notifications inbox those functions write for the app's
/// in-header notification bell.
class NotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  NotificationService({FirebaseMessaging? messaging, FirebaseFirestore? db})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = db ?? FirebaseFirestore.instance;

  Future<void> initForUser(String uid) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);
    _messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).collection('fcmTokens').doc(token).set({
      'token': token,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Foreground messages don't auto-show a system banner — call this in
  /// main.dart and surface [RemoteMessage.notification] however the app's
  /// UI layer prefers (e.g. a SnackBar).
  void onForegroundMessage(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watchNotifications(String uid) {
    return _inbox(uid).orderBy('createdAt', descending: true).limit(50).snapshots().map(
          (snap) => snap.docs.map((d) => AppNotification.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<int> watchUnreadCount(String uid) {
    return _inbox(uid).where('read', isEqualTo: false).snapshots().map((snap) => snap.docs.length);
  }

  Future<void> markRead(String uid, String notificationId) {
    return _inbox(uid).doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead(String uid) async {
    final unread = await _inbox(uid).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
