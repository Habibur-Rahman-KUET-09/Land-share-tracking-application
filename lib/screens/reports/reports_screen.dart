import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/builder_payment.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/builder_payment_service.dart';
import '../../services/contribution_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/excel_export_service.dart';
import '../../services/group_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/user_directory.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/member_name.dart';
import '../billing/upgrade_screen.dart';

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

  Future<Map<String, String>> _resolveMemberNames(List<GroupMember> members) {
    return UserDirectory.instance.names(members.map((m) => m.uid));
  }

  Future<void> _withExportData(
    Future<void> Function(
      List<GroupMember> members,
      List<Contribution> approved,
      List<BuilderPayment> payments,
      Map<String, String> names,
    )
    share,
  ) async {
    // Report download is a paid feature; with monetization off this always
    // passes and the export runs exactly as before.
    final check = EntitlementService.export(widget.group);
    if (check.blocked) {
      await showUpgradePrompt(context, group: widget.group, reasonKey: check.reasonKey!);
      return;
    }
    setState(() => _exporting = true);
    try {
      final members = await GroupService().watchMembers(widget.group.id).first;
      final contributions = await ContributionService().watchGroupContributions(widget.group.id).first;
      final approved = contributions.where((c) => c.status == ContributionStatus.approved).toList();
      final payments = await BuilderPaymentService().watch(widget.group.id).first;
      final names = await _resolveMemberNames(members);
      await share(members, approved, payments, names);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// iPadOS puts the share sheet in a popover and needs to know what to
  /// anchor it to; with nothing to point at it refuses to open. The screen's
  /// own rect is a reasonable anchor — the sheet lands over the report.
  /// Phones and browsers ignore this entirely.
  Rect? _sharePosition() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export({required bool pdf}) {
    final anchor = _sharePosition();
    return _withExportData((members, approved, payments, names) {
      return pdf
          ? PdfExportService.generateAndShare(
              group: widget.group,
              members: members,
              approvedContributions: approved,
              builderPayments: payments,
              memberNames: names,
              sharePosition: anchor,
            )
          : ExcelExportService.generateAndShare(
              group: widget.group,
              members: members,
              approvedContributions: approved,
              builderPayments: payments,
              memberNames: names,
              sharePosition: anchor,
            );
    });
  }

  Future<void> _exportMatrix({required bool pdf}) {
    final anchor = _sharePosition();
    return _withExportData((members, approved, payments, names) {
      return pdf
          ? PdfExportService.generateMonthlyMatrixAndShare(
              group: widget.group,
              members: members,
              approvedContributions: approved,
              builderPayments: payments,
              memberNames: names,
              sharePosition: anchor,
            )
          : ExcelExportService.generateMonthlyMatrixAndShare(
              group: widget.group,
              members: members,
              approvedContributions: approved,
              builderPayments: payments,
              memberNames: names,
              sharePosition: anchor,
            );
    });
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
            // Two reports that answer different questions, each said plainly
            // enough that nobody has to download one to find out which.
            _ReportCard(
              icon: Icons.summarize_outlined,
              iconColor: AppColors.primary,
              title: S.t(context, 'general_report'),
              description: S.t(context, 'general_report_desc'),
              busy: _exporting,
              onPdf: () => _export(pdf: true),
              onExcel: () => _export(pdf: false),
            ),
            const SizedBox(height: 12),
            _ReportCard(
              icon: Icons.grid_view_outlined,
              iconColor: AppColors.roleCreatorFg,
              title: S.t(context, 'matrix_report'),
              description: S.t(context, 'matrix_report_desc'),
              busy: _exporting,
              onPdf: () => _exportMatrix(pdf: true),
              onExcel: () => _exportMatrix(pdf: false),
            ),
            const SizedBox(height: 24),
            _CollapsibleSection(
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.roleCollectorFg,
              label: S.t(context, 'individual_history'),
              children: [
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
                    stream: ContributionService()
                        .watchMemberContributions(widget.group.id, _selectedMemberId!),
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
                                  title: Text(
                                      '${c.month}/${c.year} — ${CurrencyFormatter.format(c.amount)}'),
                                  subtitle: Text(S.t(context, 'method_${c.method.name}')),
                                  trailing: Text(S.t(context, 'status_${_statusKey(c.status)}')),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _CollapsibleSection(
              icon: Icons.account_balance_outlined,
              iconColor: AppColors.primary,
              label: S.t(context, 'builder_ledger'),
              children: [
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
                                leading: const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Color(0x1A0F6E5C),
                                  foregroundColor: AppColors.primary,
                                  child: Icon(Icons.payments_outlined, size: 16),
                                ),
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

/// A section that can be folded away.
///
/// Both lists below the reports can run to dozens of rows — pick a member
/// with four years of history and the builder ledger underneath is pushed
/// off the screen with no way back except scrolling past all of it. Each
/// one now collapses, and stays open by default so nothing moves for
/// anyone who liked it as it was.
class _CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    icon: widget.icon,
                    iconColor: widget.iconColor,
                    label: widget.label,
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.expand_more, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          ...widget.children,
        ],
      ],
    );
  }
}

/// One report: what it is, what is in it, and the two ways to take it away.
class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool busy;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  const _ReportCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.busy,
    required this.onPdf,
    required this.onExcel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: icon, iconColor: iconColor, label: title),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.bodyText),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(S.t(context, 'export_pdf')),
                    onPressed: busy ? null : onPdf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.grid_on_outlined),
                    label: Text(S.t(context, 'export_excel')),
                    onPressed: busy ? null : onExcel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _SectionHeader({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.heading)),
      ],
    );
  }
}
