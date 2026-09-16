// Pure unit tests for the parts of the app that don't need a live Firebase
// project (see README.md "Firebase setup") — pumping the real widget tree
// would call Firebase.initializeApp() against placeholder options.
import 'package:flutter_test/flutter_test.dart';

import 'package:land_installment_tracker/models/contribution.dart';
import 'package:land_installment_tracker/models/group_member.dart';
import 'package:land_installment_tracker/models/land_group.dart';
import 'package:land_installment_tracker/utils/currency_formatter.dart';
import 'package:land_installment_tracker/utils/due_calculator.dart';

void main() {
  test('CurrencyFormatter groups amounts using Bangladeshi (lakh) style', () {
    expect(CurrencyFormatter.format(1425000), '৳ 14,25,000');
    expect(CurrencyFormatter.format(500), '৳ 500');
    expect(CurrencyFormatter.format(1234567), '৳ 12,34,567');
    expect(CurrencyFormatter.format(0), '৳ 0');
  });

  group('computeMemberMonthStatus (FR 7 "Auto-calculated Due Amount")', () {
    final group = LandGroup(
      id: 'g1',
      name: 'টেস্ট গ্রুপ',
      landLocation: 'ঢাকা',
      totalLandValue: 1000000,
      totalInstallments: 24,
      monthlyTotalToBuilder: 30000,
      dueDayOfMonth: 10,
      contributionType: ContributionType.equal,
      createdBy: 'u1',
      createdAt: DateTime(2026, 1, 1),
      memberIds: const ['u1', 'u2', 'u3'],
    );
    final member = GroupMember(
      uid: 'u2',
      groupId: 'g1',
      role: GroupRole.member,
      monthlyAmount: 10000,
      status: MemberStatus.active,
      joinedAt: DateTime(2026, 1, 1),
    );

    test('no entries -> fully due', () {
      final status =
          computeMemberMonthStatus(member: member, group: group, allContributionsForMember: [], month: 9, year: 2026);
      expect(status.paidAmount, 0);
      expect(status.dueAmount, 10000);
      expect(status.isFullyPaid, isFalse);
      expect(status.isPartial, isFalse);
    });

    test('an approved entry for a different month is ignored', () {
      final entries = [
        Contribution(
          id: 'c1',
          groupId: 'g1',
          memberId: 'u2',
          month: 8,
          year: 2026,
          amount: 10000,
          method: PaymentMethod.bkash,
          receiptUrl: 'r1',
          status: ContributionStatus.approved,
          submittedBy: 'u2',
          submittedAt: DateTime(2026, 8, 5),
        ),
      ];
      final status = computeMemberMonthStatus(
        member: member,
        group: group,
        allContributionsForMember: entries,
        month: 9,
        year: 2026,
      );
      expect(status.dueAmount, 10000);
    });

    test('a partial approved entry leaves a partial due, not counted as pending', () {
      final entries = [
        Contribution(
          id: 'c1',
          groupId: 'g1',
          memberId: 'u2',
          month: 9,
          year: 2026,
          amount: 4000,
          method: PaymentMethod.cash,
          receiptUrl: 'r1',
          status: ContributionStatus.approved,
          submittedBy: 'u2',
          submittedAt: DateTime(2026, 9, 3),
        ),
        Contribution(
          id: 'c2',
          groupId: 'g1',
          memberId: 'u2',
          month: 9,
          year: 2026,
          amount: 1000,
          method: PaymentMethod.cash,
          receiptUrl: null,
          status: ContributionStatus.pendingConfirmation,
          submittedBy: 'u2',
          submittedAt: DateTime(2026, 9, 4),
        ),
      ];
      final status = computeMemberMonthStatus(
        member: member,
        group: group,
        allContributionsForMember: entries,
        month: 9,
        year: 2026,
      );
      expect(status.paidAmount, 4000);
      expect(status.pendingAmount, 1000);
      expect(status.dueAmount, 6000);
      expect(status.isPartial, isTrue);
      expect(status.isFullyPaid, isFalse);
    });

    test('a rejected entry never counts toward paidAmount', () {
      final entries = [
        Contribution(
          id: 'c1',
          groupId: 'g1',
          memberId: 'u2',
          month: 9,
          year: 2026,
          amount: 10000,
          method: PaymentMethod.bkash,
          receiptUrl: 'r1',
          status: ContributionStatus.rejected,
          submittedBy: 'u2',
          submittedAt: DateTime(2026, 9, 2),
          rejectReason: 'রিসিট অস্পষ্ট',
        ),
      ];
      final status = computeMemberMonthStatus(
        member: member,
        group: group,
        allContributionsForMember: entries,
        month: 9,
        year: 2026,
      );
      expect(status.paidAmount, 0);
      expect(status.dueAmount, 10000);
    });

    test('a cancelled entry never counts toward paidAmount', () {
      final entries = [
        Contribution(
          id: 'c1',
          groupId: 'g1',
          memberId: 'u2',
          month: 9,
          year: 2026,
          amount: 10000,
          method: PaymentMethod.bkash,
          receiptUrl: 'r1',
          status: ContributionStatus.cancelled,
          submittedBy: 'u2',
          submittedAt: DateTime(2026, 9, 2),
          cancelReason: 'ভুলবশত অনুমোদিত হয়েছিল',
        ),
      ];
      final status = computeMemberMonthStatus(
        member: member,
        group: group,
        allContributionsForMember: entries,
        month: 9,
        year: 2026,
      );
      expect(status.paidAmount, 0);
      expect(status.dueAmount, 10000);
    });

    test('full approved payment -> isFullyPaid', () {
      final entries = [
        Contribution(
          id: 'c1',
          groupId: 'g1',
          memberId: 'u2',
          month: 9,
          year: 2026,
          amount: 10000,
          method: PaymentMethod.bank,
          receiptUrl: 'r1',
          status: ContributionStatus.approved,
          submittedBy: 'u2',
          submittedAt: DateTime(2026, 9, 3),
        ),
      ];
      final status = computeMemberMonthStatus(
        member: member,
        group: group,
        allContributionsForMember: entries,
        month: 9,
        year: 2026,
      );
      expect(status.isFullyPaid, isTrue);
      expect(status.dueAmount, 0);
    });
  });
}
