import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/builder_payment.dart';
import 'audit_service.dart';

/// FR 2.4: what an Admin actually remitted to the land's builder/developer.
class BuilderPaymentService {
  final FirebaseFirestore _db;
  final AuditService _audit;

  BuilderPaymentService({FirebaseFirestore? db, AuditService? audit})
      : _db = db ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('builderPayments');

  Future<String> record({
    required String groupId,
    required double amount,
    required DateTime date,
    String? referenceNumber,
    String? receiptUrl,
    required String recordedBy,
  }) async {
    final ref = _col(groupId).doc();
    final payment = BuilderPayment(
      id: ref.id,
      groupId: groupId,
      amount: amount,
      date: date,
      referenceNumber: referenceNumber,
      receiptUrl: receiptUrl,
      recordedBy: recordedBy,
      recordedAt: DateTime.now(),
    );
    await ref.set(payment.toMap());
    await _audit.log(
      groupId: groupId,
      actorId: recordedBy,
      action: 'record_builder_payment',
      targetType: 'builderPayment',
      targetId: ref.id,
      details: 'বিল্ডারকে জমার এন্ট্রি যোগ করা হয়েছে',
    );
    return ref.id;
  }

  /// Newest first. The query already orders by date; the second sort settles
  /// same-day payments by when they were recorded, which a migrated group
  /// has plenty of — several months handed over on one day come back in
  /// whatever order the index returns them otherwise.
  Stream<List<BuilderPayment>> watch(String groupId) {
    return _col(groupId).orderBy('date', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => BuilderPayment.fromMap(groupId, d.id, d.data())).toList()
            ..sort((a, b) {
              final byDate = b.date.compareTo(a.date);
              return byDate != 0 ? byDate : b.recordedAt.compareTo(a.recordedAt);
            }),
        );
  }
}
