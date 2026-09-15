import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/builder_payment.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/builder_payment_service.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
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

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _row(context, S.t(context, 'total_collected'), totalCollected, bold: true),
                            const Divider(),
                            _row(context, S.t(context, 'total_remitted'), totalRemitted, bold: true),
                            const Divider(),
                            _row(context, S.t(context, 'difference'), totalCollected - totalRemitted, bold: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(S.t(context, 'members'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...members.map((m) {
                      final paidTotal =
                          approved.where((c) => c.memberId == m.uid).fold<double>(0, (s, c) => s + c.amount);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: MemberName(uid: m.uid),
                          subtitle: Text('${CurrencyFormatter.format(m.monthlyAmount)}/মাস'),
                          trailing: Text(
                            CurrencyFormatter.format(paidTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _row(BuildContext context, String label, double amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(CurrencyFormatter.format(amount), style: style),
        ],
      ),
    );
  }
}
