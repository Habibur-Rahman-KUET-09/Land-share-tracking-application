import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_user.dart';
import '../../models/builder_payment.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/builder_payment_service.dart';
import '../../services/contribution_service.dart';
import '../../services/excel_export_service.dart';
import '../../services/group_service.dart';
import '../../services/pdf_export_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/member_name.dart';

/// FR 2.7 (Reports & History): individual payment history + PDF/Excel
/// export of the whole group's report. Admin/Creator only.
class ReportsScreen extends StatefulWidget {
  final LandGroup group;
  final bool canView;
  const ReportsScreen({super.key, required this.group, required this.canView});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedMemberId;
  bool _exporting = false;

  Future<Map<String, String>> _resolveMemberNames(List<GroupMember> members) async {
    final names = <String, String>{};
    for (final m in members) {
      final snap = await FirebaseFirestore.instance.collection('users').doc(m.uid).get();
      names[m.uid] = snap.exists ? AppUser.fromMap(m.uid, snap.data()!).name : m.uid;
    }
    return names;
  }

  Future<void> _export({required bool pdf}) async {
    setState(() => _exporting = true);
    try {
      final members = await GroupService().watchMembers(widget.group.id).first;
      final contributions = await ContributionService().watchGroupContributions(widget.group.id).first;
      final approved = contributions.where((c) => c.status == ContributionStatus.approved).toList();
      final payments = await BuilderPaymentService().watch(widget.group.id).first;
      final names = await _resolveMemberNames(members);

      if (pdf) {
        await PdfExportService.generateAndShare(
          group: widget.group,
          members: members,
          approvedContributions: approved,
          builderPayments: payments,
          memberNames: names,
        );
      } else {
        await ExcelExportService.generateAndShare(
          group: widget.group,
          members: members,
          approvedContributions: approved,
          builderPayments: payments,
          memberNames: names,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canView) {
      return EmptyState(icon: Icons.lock_outline, message: S.t(context, 'no_permission'));
    }
    return StreamBuilder<List<GroupMember>>(
      stream: GroupService().watchMembers(widget.group.id),
      builder: (context, memberSnap) {
        final members = (memberSnap.data ?? []).where((m) => m.isActive).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(S.t(context, 'export_pdf')),
                    onPressed: _exporting ? null : () => _export(pdf: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.grid_on_outlined),
                    label: Text(S.t(context, 'export_excel')),
                    onPressed: _exporting ? null : () => _export(pdf: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(S.t(context, 'individual_history'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedMemberId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: Text(S.t(context, 'members')),
              items: members
                  .map((m) => DropdownMenuItem(value: m.uid, child: MemberName(uid: m.uid)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMemberId = v),
            ),
            const SizedBox(height: 12),
            if (_selectedMemberId != null)
              StreamBuilder<List<Contribution>>(
                stream: ContributionService().watchMemberContributions(widget.group.id, _selectedMemberId!),
                builder: (context, snap) {
                  final entries = snap.data ?? [];
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('কোনো এন্ট্রি নেই।', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: entries
                        .map(
                          (c) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              title: Text('${c.month}/${c.year} — ${CurrencyFormatter.format(c.amount)}'),
                              subtitle: Text(S.t(context, 'method_${c.method.name}')),
                              trailing: Text(S.t(context, 'status_${_statusKey(c.status)}')),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            const SizedBox(height: 24),
            Text(S.t(context, 'builder_ledger'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<List<BuilderPayment>>(
              stream: BuilderPaymentService().watch(widget.group.id),
              builder: (context, snap) {
                final payments = snap.data ?? [];
                if (payments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('কোনো এন্ট্রি নেই।', style: TextStyle(color: Colors.grey)),
                  );
                }
                return Column(
                  children: payments
                      .map(
                        (p) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            dense: true,
                            title: Text(CurrencyFormatter.format(p.amount)),
                            subtitle: Text('${p.date.day}-${p.date.month}-${p.date.year}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _statusKey(ContributionStatus status) {
    switch (status) {
      case ContributionStatus.approved:
        return 'approved';
      case ContributionStatus.rejected:
        return 'rejected';
      case ContributionStatus.cancelled:
        return 'cancelled';
      case ContributionStatus.pendingConfirmation:
        return 'pending';
    }
  }
}
