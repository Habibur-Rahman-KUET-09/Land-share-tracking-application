import 'package:cloud_firestore/cloud_firestore.dart';

/// FR 2.3 / Finalized Decision 3: Member submits -> "Pending Confirmation"
/// -> an Admin (never the submitter themselves — Maker-Checker) Approves or
/// Rejects (with a reason, FR 7 "Reject with Reason").
enum ContributionStatus { pendingConfirmation, approved, rejected }

ContributionStatus contributionStatusFromString(String? v) {
  switch (v) {
    case 'approved':
      return ContributionStatus.approved;
    case 'rejected':
      return ContributionStatus.rejected;
    default:
      return ContributionStatus.pendingConfirmation;
  }
}

enum PaymentMethod { cash, bkash, bank, other }

PaymentMethod paymentMethodFromString(String? v) {
  switch (v) {
    case 'bkash':
      return PaymentMethod.bkash;
    case 'bank':
      return PaymentMethod.bank;
    case 'other':
      return PaymentMethod.other;
    default:
      return PaymentMethod.cash;
  }
}

/// A single monthly-contribution entry (groups/{groupId}/contributions/{id}).
///
/// One member can have multiple entries in the same month (FR "Partial
/// payment support" — e.g. two part-payments); the month's total paid is the
/// sum of that member+month's APPROVED entries. [receiptUrl] is mandatory
/// before an Admin may approve (FR 7 "Payment Proof Upload (Mandatory)").
class Contribution {
  final String id;
  final String groupId;
  final String memberId;
  final int month; // 1-12
  final int year;
  final double amount;
  final PaymentMethod method;
  final String? receiptUrl;
  final ContributionStatus status;
  final String submittedBy;
  final DateTime submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectReason;

  const Contribution({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.month,
    required this.year,
    required this.amount,
    required this.method,
    this.receiptUrl,
    required this.status,
    required this.submittedBy,
    required this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectReason,
  });

  /// FR 7 "Late Payment Tracking" — approved after the group's due date for
  /// that month counts as late.
  bool isLate(int dueDayOfMonth) {
    if (status != ContributionStatus.approved || approvedAt == null) return false;
    final due = DateTime(year, month, dueDayOfMonth);
    return submittedAt.isAfter(due);
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'month': month,
      'year': year,
      'amount': amount,
      'method': method.name,
      'receiptUrl': receiptUrl,
      'status': status.name == 'pendingConfirmation' ? 'pendingConfirmation' : status.name,
      'submittedBy': submittedBy,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'rejectReason': rejectReason,
    };
  }

  factory Contribution.fromMap(String groupId, String id, Map<String, dynamic> map) {
    return Contribution(
      id: id,
      groupId: groupId,
      memberId: (map['memberId'] as String?) ?? '',
      month: (map['month'] as num?)?.toInt() ?? 1,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: paymentMethodFromString(map['method'] as String?),
      receiptUrl: map['receiptUrl'] as String?,
      status: contributionStatusFromString(map['status'] as String?),
      submittedBy: (map['submittedBy'] as String?) ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedBy: map['approvedBy'] as String?,
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      rejectReason: map['rejectReason'] as String?,
    );
  }
}
