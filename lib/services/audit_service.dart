import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/audit_log_entry.dart';

/// FR 7 "Audit Trail/Activity Log". A thin, shared write/read helper so
/// every other service (group/contribution/builder-payment) logs actions
/// the same way, without duplicating the collection path logic.
class AuditService {
  final FirebaseFirestore _db;
  AuditService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('auditLog');

  Future<void> log({
    required String groupId,
    required String actorId,
    required String action,
    required String targetType,
    required String targetId,
    required String details,
  }) async {
    await _col(groupId).add({
      'actorId': actorId,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'details': details,
      'timestamp': Timestamp.now(),
    });
  }

  Stream<List<AuditLogEntry>> watch(String groupId) {
    return _col(groupId).orderBy('timestamp', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => AuditLogEntry.fromMap(groupId, d.id, d.data())).toList(),
        );
  }
}
