import '../models/contribution.dart';
import '../models/group_member.dart';
import '../models/land_group.dart';

/// FR 7 "Auto-calculated Due Amount" — pure calculation, no I/O, so it's
/// reused identically by the dashboard, transparency ledger, and reports.
class MemberMonthStatus {
  final String memberId;
  final int month;
  final int year;
  final double expectedAmount;
  final double paidAmount; // sum of APPROVED entries only
  final double pendingAmount; // sum of entries still awaiting approval
  final double dueAmount; // max(0, expected - paid)
  final bool isLate;

  const MemberMonthStatus({
    required this.memberId,
    required this.month,
    required this.year,
    required this.expectedAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.dueAmount,
    required this.isLate,
  });

  bool get isFullyPaid => dueAmount <= 0.005;
  bool get isPartial => paidAmount > 0.005 && !isFullyPaid;
}

MemberMonthStatus computeMemberMonthStatus({
  required GroupMember member,
  required LandGroup group,
  required List<Contribution> allContributionsForMember,
  required int month,
  required int year,
}) {
  final thisMonth = allContributionsForMember.where((c) => c.month == month && c.year == year);
  final paid = thisMonth
      .where((c) => c.status == ContributionStatus.approved)
      .fold<double>(0, (sum, c) => sum + c.amount);
  final pending = thisMonth
      .where((c) => c.status == ContributionStatus.pendingConfirmation)
      .fold<double>(0, (sum, c) => sum + c.amount);
  final due = (member.monthlyAmount - paid).clamp(0, double.infinity).toDouble();

  final today = DateTime.now();
  final dueDate = DateTime(year, month, group.dueDayOfMonth);
  final isLate = due > 0.005 && today.isAfter(dueDate);

  return MemberMonthStatus(
    memberId: member.uid,
    month: month,
    year: year,
    expectedAmount: member.monthlyAmount,
    paidAmount: paid,
    pendingAmount: pending,
    dueAmount: due,
    isLate: isLate,
  );
}
