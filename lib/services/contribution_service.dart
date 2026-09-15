import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contribution.dart';
import 'audit_service.dart';

/// FR 2.3 (Monthly Contribution Collection) + Finalized Decisions 2 & 3
/// (multi-Admin Maker-Checker: no one can approve their own submission).
class ContributionService {
  final FirebaseFirestore _db;
  final AuditService _audit;

  ContributionService({FirebaseFirestore? db, AuditService? audit})
      : _db = db ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('contributions');

  /// FR 7 "Payment Proof Upload (Mandatory)" is enforced by the UI requiring
  /// a receipt before this is called for anything past "pending" — but the
  /// receipt itself is attached here since it's captured at submission time.
  Future<String> submit({
    required String groupId,
    required String memberId,
    required int month,
    required int year,
    required double amount,
    required PaymentMethod method,
    String? receiptUrl,
    required String submittedBy,
  }) async {
    final ref = _col(groupId).doc();
    final contribution = Contribution(
      id: ref.id,
      groupId: groupId,
      memberId: memberId,
      month: month,
      year: year,
      amount: amount,
      method: method,
      receiptUrl: receiptUrl,
      status: ContributionStatus.pendingConfirmation,
      submittedBy: submittedBy,
      submittedAt: DateTime.now(),
    );
    await ref.set(contribution.toMap());
    await _audit.log(
      groupId: groupId,
      actorId: submittedBy,
      action: 'submit_contribution',
      targetType: 'contribution',
      targetId: ref.id,
      details: 'কিস্তি পরিশোধের এন্ট্রি জমা দেওয়া হয়েছে (অনুমোদনের অপেক্ষায়)',
    );
    return ref.id;
  }

  /// Maker-Checker guard: throws if [approverId] is the same person who
  /// submitted the entry (or the member it's for) — a different Admin must
  /// confirm it. Also refuses to approve without a receipt (FR 7).
  Future<void> approve({
    required String groupId,
    required String contributionId,
    required String approverId,
  }) async {
    final ref = _col(groupId).doc(contributionId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('এন্ট্রি খুঁজে পাওয়া যায়নি');
    final contribution = Contribution.fromMap(groupId, contributionId, snap.data()!);

    if (contribution.submittedBy == approverId || contribution.memberId == approverId) {
      throw StateError('নিজের জমা দেওয়া এন্ট্রি নিজে অনুমোদন করা যাবে না — অন্য একজন Admin কে অনুমোদন করতে হবে');
    }
    if (contribution.receiptUrl == null || contribution.receiptUrl!.isEmpty) {
      throw StateError('রিসিট/প্রমাণ ছাড়া অনুমোদন করা যাবে না');
    }
    if (contribution.status != ContributionStatus.pendingConfirmation) {
      throw StateError('এই এন্ট্রি ইতিমধ্যে প্রসেস হয়ে গেছে');
    }

    await ref.update({
      'status': 'approved',
      'approvedBy': approverId,
      'approvedAt': Timestamp.now(),
      'rejectReason': null,
    });
    await _audit.log(
      groupId: groupId,
      actorId: approverId,
      action: 'approve_contribution',
      targetType: 'contribution',
      targetId: contributionId,
      details: 'কিস্তি অনুমোদন করা হয়েছে',
    );
  }

  Future<void> reject({
    required String groupId,
    required String contributionId,
    required String approverId,
    required String reason,
  }) async {
    final ref = _col(groupId).doc(contributionId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('এন্ট্রি খুঁজে পাওয়া যায়নি');
    final contribution = Contribution.fromMap(groupId, contributionId, snap.data()!);

    if (contribution.submittedBy == approverId || contribution.memberId == approverId) {
      throw StateError('নিজের জমা দেওয়া এন্ট্রি নিজে প্রত্যাখ্যান করা যাবে না — অন্য একজন Admin করবেন');
    }
    if (reason.trim().isEmpty) {
      throw StateError('প্রত্যাখ্যানের কারণ লিখতে হবে');
    }

    await ref.update({
      'status': 'rejected',
      'approvedBy': approverId,
      'approvedAt': Timestamp.now(),
      'rejectReason': reason.trim(),
    });
    await _audit.log(
      groupId: groupId,
      actorId: approverId,
      action: 'reject_contribution',
      targetType: 'contribution',
      targetId: contributionId,
      details: 'প্রত্যাখ্যানের কারণ: ${reason.trim()}',
    );
  }

  Stream<List<Contribution>> watchGroupContributions(String groupId) {
    return _col(groupId).orderBy('submittedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data())).toList(),
        );
  }

  Stream<List<Contribution>> watchPendingApprovals(String groupId) {
    return _col(groupId)
        .where('status', isEqualTo: 'pendingConfirmation')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data())).toList());
  }

  Stream<List<Contribution>> watchMemberContributions(String groupId, String memberId) {
    return _col(groupId).where('memberId', isEqualTo: memberId).snapshots().map(
          (snap) => snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data())).toList(),
        );
  }
}
