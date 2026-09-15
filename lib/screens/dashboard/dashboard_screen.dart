import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/due_calculator.dart';
import '../../widgets/member_name.dart';

/// FR 2.5 (Dashboard & Summary): group-wise should/actual/due, per-member
/// status, monthly progress, overall % progress.
class DashboardScreen extends StatelessWidget {
  final LandGroup group;
  final String currentUid;
  const DashboardScreen({super.key, required this.group, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMember>>(
      stream: GroupService().watchMembers(group.id),
      builder: (context, memberSnap) {
        final members = (memberSnap.data ?? []).where((m) => m.isActive).toList();
        return StreamBuilder<List<Contribution>>(
          stream: ContributionService().watchGroupContributions(group.id),
          builder: (context, contribSnap) {
            final contributions = contribSnap.data ?? [];
            final approved = contributions.where((c) => c.status == ContributionStatus.approved);

            final totalCollectedAllTime = approved.fold<double>(0, (sum, c) => sum + c.amount);
            final overallPercent =
                group.totalLandValue <= 0 ? 0.0 : (totalCollectedAllTime / group.totalLandValue).clamp(0, 1.0);

            final now = DateTime.now();
            final expectedThisMonth = members.fold<double>(0, (sum, m) => sum + m.monthlyAmount);
            final collectedThisMonth = approved
                .where((c) => c.month == now.month && c.year == now.year)
                .fold<double>(0, (sum, c) => sum + c.amount);

            // মাসিক progress: কতগুলো মাসে পুরো গ্রুপের collection সম্পূর্ণ
            // হয়েছে (approved total >= সেই মাসের প্রত্যাশিত মোট)।
            final monthsSeen = approved.map((c) => '${c.year}-${c.month}').toSet();
            var monthsCompleted = 0;
            for (final key in monthsSeen) {
              final parts = key.split('-');
              final y = int.parse(parts[0]);
              final m = int.parse(parts[1]);
              final sum = approved
                  .where((c) => c.month == m && c.year == y)
                  .fold<double>(0, (s, c) => s + c.amount);
              if (sum >= group.monthlyTotalToBuilder - 0.5) monthsCompleted++;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatCard(
                  title: S.t(context, 'overall_progress'),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: overallPercent.toDouble(), minHeight: 10),
                      const SizedBox(height: 8),
                      Text('${(overallPercent * 100).toStringAsFixed(1)}%'),
                      const SizedBox(height: 4),
                      Text(
                        '${CurrencyFormatter.format(totalCollectedAllTime)} / ${CurrencyFormatter.format(group.totalLandValue)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: '${S.t(context, 'this_month')} (${now.month}/${now.year})',
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: expectedThisMonth <= 0 ? 0 : (collectedThisMonth / expectedThisMonth).clamp(0, 1.0),
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${CurrencyFormatter.format(collectedThisMonth)} / ${CurrencyFormatter.format(expectedThisMonth)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'কিস্তি অগ্রগতি',
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: group.totalInstallments <= 0
                            ? 0
                            : (monthsCompleted / group.totalInstallments).clamp(0, 1.0),
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Text('$monthsCompleted / ${group.totalInstallments} মাস সম্পূর্ণ'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('সদস্যদের এই মাসের অবস্থা', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...members.map((m) {
                  final status = computeMemberMonthStatus(
                    member: m,
                    group: group,
                    allContributionsForMember: contributions.where((c) => c.memberId == m.uid).toList(),
                    month: now.month,
                    year: now.year,
                  );
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: MemberName(uid: m.uid),
                      subtitle: Text(
                        '${CurrencyFormatter.format(status.paidAmount)} / ${CurrencyFormatter.format(status.expectedAmount)}',
                      ),
                      trailing: _memberStatusChip(context, status),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _memberStatusChip(BuildContext context, MemberMonthStatus status) {
    if (status.isFullyPaid) {
      return _chip(S.t(context, 'status_approved'), Colors.green);
    }
    if (status.isPartial) {
      return _chip(S.t(context, 'status_partial'), Colors.orange);
    }
    if (status.isLate) {
      return _chip(S.t(context, 'status_late'), Colors.red);
    }
    return _chip(S.t(context, 'status_due'), Colors.blueGrey);
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      );
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _StatCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
