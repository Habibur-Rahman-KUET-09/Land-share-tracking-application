import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/due_calculator.dart';
import '../../utils/group_type_labels.dart';
import '../../widgets/member_name.dart';
import '../../widgets/status_chip.dart';

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

            // Two different questions, and an installment plan cares about
            // the second one:
            //
            //   how many months did we collect in full?   (monthsCompleted)
            //   how many installments have we paid off?   (installmentsPaid)
            //
            // The second is money divided by the monthly installment, so
            // ৳10,000 in each of six months is three installments and a
            // ৳60,000 month is three of them too. Counting whole months
            // instead loses both: it throws away every part-month, and it
            // caps a month that paid triple at one. A group with years of
            // migrated history at an older, smaller monthly figure sees the
            // difference immediately.
            final monthsSeen = approved.map((c) => '${c.year}-${c.month}').toSet();
            var monthsCompleted = 0;
            var monthsPartial = 0;
            var partialTotal = 0.0;
            for (final key in monthsSeen) {
              final parts = key.split('-');
              final y = int.parse(parts[0]);
              final m = int.parse(parts[1]);
              final sum = approved
                  .where((c) => c.month == m && c.year == y)
                  .fold<double>(0, (s, c) => s + c.amount);
              if (sum >= group.monthlyTotalToBuilder - 0.5) {
                monthsCompleted++;
              } else {
                monthsPartial++;
                partialTotal += sum;
              }
            }

            // Whole installments; the remainder is still on its way.
            final installmentsPaid = group.monthlyTotalToBuilder <= 0
                ? 0
                : (totalCollectedAllTime / group.monthlyTotalToBuilder).floor();

            // A lottery has no end figure to progress towards, and a savings
            // group's target is optional — without one this card would read
            // "৳0 / ৳0", so it's dropped rather than shown empty.
            final hasTarget = group.totalLandValue > 0;

            // A lottery runs exactly one round per member, so its length is
            // the membership rather than a planned installment count.
            final usesInstallments = group.groupType.hasInstallmentCount;
            final totalMonths = usesInstallments ? group.totalInstallments : members.length;

            // A lottery or savings cycle is measured in rounds taken, not in
            // money divided by anything — there, a completed month is still
            // the honest unit.
            final progressCount = usesInstallments ? installmentsPaid : monthsCompleted;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (hasTarget) ...[
                  _StatCard(
                    title: S.t(context, 'overall_progress'),
                    icon: Icons.trending_up,
                    iconColor: AppColors.approvedFg,
                    child: Column(
                      children: [
                        _ProgressBar(value: overallPercent.toDouble(), color: AppColors.approvedFg),
                        const SizedBox(height: 10),
                        Text(
                          '${(overallPercent * 100).toStringAsFixed(1)}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.heading),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${CurrencyFormatter.format(totalCollectedAllTime)} / ${CurrencyFormatter.format(group.totalLandValue)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _StatCard(
                  title: '${S.t(context, 'this_month')} (${now.month}/${now.year})',
                  icon: Icons.calendar_month_outlined,
                  iconColor: AppColors.pendingFg,
                  child: Column(
                    children: [
                      _ProgressBar(
                        value: expectedThisMonth <= 0 ? 0 : (collectedThisMonth / expectedThisMonth).clamp(0, 1.0),
                        color: AppColors.pendingFg,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${CurrencyFormatter.format(collectedThisMonth)} / ${CurrencyFormatter.format(expectedThisMonth)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.heading),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: S.t(
                    context,
                    group.groupType.hasInstallmentCount ? 'installment_progress' : 'cycle_progress',
                  ),
                  icon: Icons.flag_outlined,
                  iconColor: AppColors.roleCreatorFg,
                  child: Column(
                    children: [
                      _ProgressBar(
                        value: totalMonths <= 0 ? 0 : (progressCount / totalMonths).clamp(0, 1.0),
                        color: AppColors.roleCreatorFg,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$progressCount / $totalMonths '
                        '${S.t(context, usesInstallments ? 'installments_complete' : 'months_complete')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.heading),
                      ),
                      if (usesInstallments) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${monthsSeen.length} ${S.t(context, 'months_collected')} · '
                          '${CurrencyFormatter.format(totalCollectedAllTime)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                        ),
                        Text(
                          '${S.t(context, 'monthly_target')} '
                          '${CurrencyFormatter.format(group.monthlyTotalToBuilder)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.mutedText),
                        ),
                      ] else if (monthsPartial > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$monthsPartial ${S.t(context, 'months_partial')} · '
                          '${CurrencyFormatter.format(partialTotal)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'সদস্যদের এই মাসের অবস্থা',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.heading),
                ),
                const SizedBox(height: 8),
                ...members.map((m) {
                  final status = computeMemberMonthStatus(
                    member: m,
                    group: group,
                    allContributionsForMember: contributions.where((c) => c.memberId == m.uid).toList(),
                    month: now.month,
                    year: now.year,
                  );
                  final (avatarBg, avatarFg) = AppColors.accentFor(m.uid);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: avatarBg,
                        foregroundColor: avatarFg,
                        child: const Icon(Icons.person, size: 20),
                      ),
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
      return StatusChip(
        label: S.t(context, 'status_approved'),
        background: AppColors.approvedBg,
        foreground: AppColors.approvedFg,
      );
    }
    if (status.isPartial) {
      return StatusChip(
        label: S.t(context, 'status_partial'),
        background: AppColors.partialBg,
        foreground: AppColors.partialFg,
      );
    }
    if (status.isLate) {
      return StatusChip(label: S.t(context, 'status_late'), background: AppColors.lateBg, foreground: AppColors.lateFg);
    }
    return StatusChip(label: S.t(context, 'status_due'), background: AppColors.dueBg, foreground: AppColors.dueFg);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _StatCard({required this.title, required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.heading),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Rounded, flat-track progress bar matching the mockups' `.bar` style.
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: value, minHeight: 8, color: color),
    );
  }
}
