import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// FR 2.6 (Notifications & Reminders) — client side: requests permission,
/// registers this device's FCM token under users/{uid}/fcmTokens/{token} so
/// the Cloud Functions in functions/ (due-date reminders, missed-payment
/// alerts, pending-approval pushes) can target this user, and surfaces
/// foreground messages via [onForegroundMessage].
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
}
