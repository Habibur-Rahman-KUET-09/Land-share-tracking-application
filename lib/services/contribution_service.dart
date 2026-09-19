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

  /// [receiptUrl] is optional — a member can submit without a photo receipt.
  ///
  /// [singleManager] is the group's "one man army" mode: there is nobody
  /// else to approve, so the entry is booked as approved on the spot and
  /// the manager may record it for any member — which is why [memberId] is
  /// free to differ from [submittedBy] there.
  Future<String> submit({
    required String groupId,
    required String memberId,
    required int month,
    required int year,
    required double amount,
    required PaymentMethod method,
    String? receiptUrl,
    required String submittedBy,
    bool singleManager = false,
  }) async {
    final ref = _col(groupId).doc();
    final now = DateTime.now();
    final contribution = Contribution(
      id: ref.id,
      groupId: groupId,
      memberId: memberId,
      month: month,
      year: year,
      amount: amount,
      method: method,
      receiptUrl: receiptUrl,
      status: singleManager ? ContributionStatus.approved : ContributionStatus.pendingConfirmation,
      submittedBy: submittedBy,
      submittedAt: now,
      approvedBy: singleManager ? submittedBy : null,
      approvedAt: singleManager ? now : null,
    );
    await ref.set(contribution.toMap());
    await _audit.log(
      groupId: groupId,
      actorId: submittedBy,
      action: 'submit_contribution',
      targetType: 'contribution',
      targetId: ref.id,
      details: singleManager
          ? 'কিস্তি পরিশোধের এন্ট্রি যোগ করা হয়েছে'
          : 'কিস্তি পরিশোধের এন্ট্রি জমা দেওয়া হয়েছে (অনুমোদনের অপেক্ষায়)',
    );
    return ref.id;
  }

  /// Maker-Checker guard: throws if [approverId] is the same person who
  /// submitted the entry (or the member it's for) — a different Admin or
  /// Collector must confirm it. A receipt is not required.
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
      throw StateError('নিজের জমা দেওয়া এন্ট্রি নিজে অনুমোদন করা যাবে না — অন্য একজন Admin/Collector কে অনুমোদন করতে হবে');
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

  /// Voids an already-approved entry (Admin/Creator only — enforced by
  /// firestore.rules). Distinct from [reject]: reject only applies to a
  /// still-pending entry; this reverses a decision that already happened.
  Future<void> cancel({
    required String groupId,
    required String contributionId,
    required String cancelledBy,
    required String reason,
  }) async {
    final ref = _col(groupId).doc(contributionId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('এন্ট্রি খুঁজে পাওয়া যায়নি');
    final contribution = Contribution.fromMap(groupId, contributionId, snap.data()!);

    if (contribution.status != ContributionStatus.approved) {
      throw StateError('শুধু অনুমোদিত এন্ট্রি বাতিল করা যাবে');
    }
    if (reason.trim().isEmpty) {
      throw StateError('বাতিলের কারণ লিখতে হবে');
    }

    await ref.update({
      'status': 'cancelled',
      'cancelledBy': cancelledBy,
      'cancelledAt': Timestamp.now(),
      'cancelReason': reason.trim(),
    });
    await _audit.log(
      groupId: groupId,
      actorId: cancelledBy,
      action: 'cancel_contribution',
      targetType: 'contribution',
      targetId: contributionId,
      details: 'বাতিলের কারণ: ${reason.trim()}',
    );
  }

  /// Newest first, by the month the entry is *for* rather than the moment
  /// it was typed. Those differ more often than they agree: a migrated
  /// group's four years of history all carry the same submittedAt (the
  /// import), and a member catching up on three months files them minutes
  /// apart. Ordering by the period is what a ledger means by "by date".
  ///
  /// Sorted here rather than in the query because ordering by year and
  /// month together, alongside the where() clauses these streams already
  /// use, would need a composite index per combination. The lists are
  /// already fully in memory, and a group's history is hundreds of rows,
  /// not millions.
  static int _newestFirst(Contribution a, Contribution b) {
    final period = DateTime(b.year, b.month).compareTo(DateTime(a.year, a.month));
    if (period != 0) return period;
    return b.submittedAt.compareTo(a.submittedAt);
  }

  static List<Contribution> _sorted(Iterable<Contribution> entries) =>
      entries.toList()..sort(_newestFirst);

  Stream<List<Contribution>> watchGroupContributions(String groupId) {
    return _col(groupId).snapshots().map(
          (snap) => _sorted(snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data()))),
        );
  }

  Stream<List<Contribution>> watchPendingApprovals(String groupId) {
    return _col(groupId)
        .where('status', isEqualTo: 'pendingConfirmation')
        .snapshots()
        .map((snap) =>
            _sorted(snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data()))));
  }

  /// Just one month's entries, for screens that only ever show a single
  /// month — the lottery pot, most obviously. Two equality filters merge
  /// single-field indexes, so this needs no composite index.
  ///
  /// The alternative (streaming the group's whole history and filtering in
  /// Dart) bills a read per document every time the screen opens, and grows
  /// without bound as the group ages.
  Stream<List<Contribution>> watchMonth(String groupId, int month, int year) {
    return _col(groupId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snap) =>
            _sorted(snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data()))));
  }

  Stream<List<Contribution>> watchMemberContributions(String groupId, String memberId) {
    return _col(groupId).where('memberId', isEqualTo: memberId).snapshots().map(
          (snap) => _sorted(snap.docs.map((d) => Contribution.fromMap(groupId, d.id, d.data()))),
        );
  }
}
