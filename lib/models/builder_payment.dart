import 'package:cloud_firestore/cloud_firestore.dart';

/// FR 2.4: a single payment an Admin remitted to the land's builder/developer
/// (groups/{groupId}/builderPayments/{id}).
class BuilderPayment {
  final String id;
  final String groupId;
  final double amount;
  final DateTime date;
  final String? referenceNumber;
  final String? receiptUrl;
  final String recordedBy;
  final DateTime recordedAt;

  const BuilderPayment({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.date,
    this.referenceNumber,
    this.receiptUrl,
    required this.recordedBy,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'referenceNumber': referenceNumber,
      'receiptUrl': receiptUrl,
      'recordedBy': recordedBy,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  factory BuilderPayment.fromMap(String groupId, String id, Map<String, dynamic> map) {
    return BuilderPayment(
      id: id,
      groupId: groupId,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      referenceNumber: map['referenceNumber'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
      recordedBy: (map['recordedBy'] as String?) ?? '',
      recordedAt: (map['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
