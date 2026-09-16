import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/builder_payment.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/builder_payment_service.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/member_name.dart';

/// FR 2.8 "Transparency Feature" — সব member যেন গ্রুপের সম্মিলিত হিসাব
/// দেখতে পারে (কে কত দিয়েছে, মোট কত জমা হয়েছে, বিল্ডারকে কত দেওয়া হয়েছে)।
/// Read-only for everyone — only Admins get edit actions, and those live on
/// the Members/Contributions/Builder-Payments tabs, not here.
class TransparencyScreen extends StatelessWidget {
  final LandGroup group;
  const TransparencyScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMember>>(
      stream: GroupService().watchMembers(group.id),
      builder: (context, memberSnap) {
        final members = (memberSnap.data ?? []).where((m) => m.isActive).toList();
        return StreamBuilder<List<Contribution>>(
          stream: ContributionService().watchGroupContributions(group.id),
          builder: (context, contribSnap) {
            final approved = (contribSnap.data ?? [])
                .where((c) => c.status == ContributionStatus.approved)
                .toList();
            return StreamBuilder<List<BuilderPayment>>(
              stream: BuilderPaymentService().watch(group.id),
              builder: (context, paymentSnap) {
                final payments = paymentSnap.data ?? [];
                final totalCollected = approved.fold<double>(0, (s, c) => s + c.amount);
                final totalRemitted = payments.fold<double>(0, (s, p) => s + p.amount);
                final difference = totalCollected - totalRemitted;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _row(
                              context,
                              S.t(context, 'total_collected'),
                              totalCollected,
                              icon: Icons.trending_up,
                              iconColor: AppColors.approvedFg,
                            ),
                            _row(
                              context,
                              S.t(context, 'total_remitted'),
                              totalRemitted,
                              icon: Icons.account_balance_outlined,
                              iconColor: AppColors.roleCollectorFg,
                            ),
                            _row(
                              context,
                              S.t(context, 'difference'),
                              difference,
                              icon: Icons.balance_outlined,
                              iconColor: AppColors.roleAdminFg,
                              isLast: true,
                              negative: difference < 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      S.t(context, 'members'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.heading),
                    ),
                    const SizedBox(height: 8),
                    ...members.map((m) {
                      final paidTotal =
                          approved.where((c) => c.memberId == m.uid).fold<double>(0, (s, c) => s + c.amount);
                      final (avatarBg, avatarFg) = AppColors.accentFor(m.uid);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border, width: 0.6),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: avatarBg,
                            foregroundColor: avatarFg,
                            child: const Icon(Icons.person, size: 20),
                          ),
                          title: MemberName(uid: m.uid),
                          subtitle: Text('${CurrencyFormatter.format(m.monthlyAmount)}/মাস'),
                          trailing: Text(
                            CurrencyFormatter.format(paidTotal),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: AppColors.heading),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double amount, {
    required IconData icon,
    required Color iconColor,
    bool isLast = false,
    bool negative = false,
  }) {
    final valueColor = negative ? AppColors.negative : AppColors.heading;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: isLast
          ? null
          : const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.6))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.heading)),
            ],
          ),
          Text(
            '${negative ? '-' : ''}${CurrencyFormatter.format(amount.abs())}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: valueColor),
          ),
        ],
      ),
    );
  }
}
