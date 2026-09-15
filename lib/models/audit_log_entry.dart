import 'package:cloud_firestore/cloud_firestore.dart';

/// FR 7 "Audit Trail/Activity Log" — কে কখন কী entry/edit/approve/reject
/// করলো তার সম্পূর্ণ লগ (groups/{groupId}/auditLog/{id}). Append-only —
/// written once alongside the action it records, never edited.
class AuditLogEntry {
  final String id;
  final String groupId;
  final String actorId;
  final String action; // e.g. 'create_contribution', 'approve', 'reject', 'edit_plan', 'add_member', 'exit_member', 'record_builder_payment'
  final String targetType; // 'contribution' | 'builderPayment' | 'plan' | 'member' | 'group'
  final String targetId;
  final String details;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.groupId,
    required this.actorId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AuditLogEntry.fromMap(String groupId, String id, Map<String, dynamic> map) {
    return AuditLogEntry(
      id: id,
      groupId: groupId,
      actorId: (map['actorId'] as String?) ?? '',
      action: (map['action'] as String?) ?? '',
      targetType: (map['targetType'] as String?) ?? '',
      targetId: (map['targetId'] as String?) ?? '',
      details: (map['details'] as String?) ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
