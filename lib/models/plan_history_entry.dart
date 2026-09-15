import 'package:cloud_firestore/cloud_firestore.dart';

/// FR Finalized Decision 4: the installment plan isn't rigid — Admin can
/// edit total installments / monthly amount / due day later, but every edit
/// is snapshotted here first (groups/{groupId}/planHistory/{id}) so
/// transparency is preserved (FR 2.8).
class PlanHistoryEntry {
  final String id;
  final String groupId;
  final int totalInstallments;
  final double monthlyTotalToBuilder;
  final int dueDayOfMonth;
  final String contributionType;
  final String editedBy;
  final DateTime editedAt;

  const PlanHistoryEntry({
    required this.id,
    required this.groupId,
    required this.totalInstallments,
    required this.monthlyTotalToBuilder,
    required this.dueDayOfMonth,
    required this.contributionType,
    required this.editedBy,
    required this.editedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalInstallments': totalInstallments,
      'monthlyTotalToBuilder': monthlyTotalToBuilder,
      'dueDayOfMonth': dueDayOfMonth,
      'contributionType': contributionType,
      'editedBy': editedBy,
      'editedAt': Timestamp.fromDate(editedAt),
    };
  }

  factory PlanHistoryEntry.fromMap(String groupId, String id, Map<String, dynamic> map) {
    return PlanHistoryEntry(
      id: id,
      groupId: groupId,
      totalInstallments: (map['totalInstallments'] as num?)?.toInt() ?? 0,
      monthlyTotalToBuilder: (map['monthlyTotalToBuilder'] as num?)?.toDouble() ?? 0,
      dueDayOfMonth: (map['dueDayOfMonth'] as num?)?.toInt() ?? 5,
      contributionType: (map['contributionType'] as String?) ?? 'equal',
      editedBy: (map['editedBy'] as String?) ?? '',
      editedAt: (map['editedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
