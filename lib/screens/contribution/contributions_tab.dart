import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../models/builder_payment.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/builder_payment_service.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/date_range_filter_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/member_name.dart';
import '../../widgets/status_chip.dart';

/// FR 2.3 (Monthly Contribution Collection) + Finalized Decisions 2 & 3:
/// members submit "Paid" entries here, and — for Admin/Collector/Creator —
/// this is also where the Maker-Checker approval queue lives.
class ContributionsTab extends StatefulWidget {
  final LandGroup group;
  final bool canApprove;
  final bool canCancel;
  final String currentUid;
  const ContributionsTab({
    super.key,
    required this.group,
    required this.canApprove,
    required this.canCancel,
    required this.currentUid,
  });

  @override
  State<ContributionsTab> createState() => _ContributionsTabState();
}

class _ContributionsTabState extends State<ContributionsTab> {
  bool _showApprovals = false;
  DateTimeRange? _range;

  /// "One man army" mode: there is no second approver, so there is no
  /// approval queue to show — the manager books entries for everyone and
  /// they land approved. See [ContributionService.submit].
  bool get _managesEveryone => widget.group.singleManager && widget.canApprove;

  /// Maker-checker means nobody approves their own entry. So if the signed-in
  /// user is the *only* active approver in the group, anything they file can
  /// never be approved by anyone — it just sits pending forever, and the
  /// group's totals quietly stop matching reality.
  ///
  /// Rather than let them walk into that, the entry action is withheld until
  /// a second Admin/Collector exists. Other members are unaffected: their
  /// entries have an approver (this one). Single-manager groups skip the
  /// approval step entirely and are never blocked.
  ///
  /// This lives in the UI because security rules cannot count a collection —
  /// they can only read documents they are handed a path to.
  bool _isSoleApprover(List<GroupMember> members) {
    if (widget.group.singleManager || !widget.canApprove) return false;
    final approvers = members
        .where((m) => m.isActive && m.canApproveOrRejectContribution)
        .map((m) => m.uid)
        .toSet();
    return approvers.length <= 1 && approvers.contains(widget.currentUid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMember>>(
      stream: GroupService().watchMembers(widget.group.id),
      builder: (context, memberSnap) {
        return _build(context, memberSnap.data ?? const <GroupMember>[]);
      },
    );
  }

  Widget _build(BuildContext context, List<GroupMember> members) {
    final showApprovalToggle = widget.canApprove && !widget.group.singleManager;
    final soleApprover = _isSoleApprover(members);
    return Scaffold(
      body: Column(
        children: [
          if (showApprovalToggle)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(S.t(context, 'mark_paid'))),
                  ButtonSegment(value: true, label: Text(S.t(context, 'pending_approvals'))),
                ],
                selected: {_showApprovals},
                onSelectionChanged: (s) => setState(() => _showApprovals = s.first),
              ),
            ),
          if (soleApprover) const _SoleApproverNotice(),
          DateRangeFilterBar(range: _range, onChanged: (r) => setState(() => _range = r)),
          Expanded(
            child: _showApprovals && showApprovalToggle
                ? _ApprovalsList(group: widget.group, currentUid: widget.currentUid, range: _range)
                : _MyContributions(
                    group: widget.group,
                    currentUid: widget.currentUid,
                    canCancel: widget.canCancel,
                    range: _range,
                    showEveryone: _managesEveryone,
                  ),
          ),
        ],
      ),
      floatingActionButton: (_showApprovals && showApprovalToggle) || soleApprover
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _SubmitContributionDialog(
                  group: widget.group,
                  memberId: widget.currentUid,
                  managesEveryone: _managesEveryone,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(S.t(context, 'mark_paid')),
            ),
    );
  }
}

class _SoleApproverNotice extends StatelessWidget {
  const _SoleApproverNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.pendingFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.t(context, 'needs_second_approver'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.pendingFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyContributions extends StatelessWidget {
  final LandGroup group;
  final String currentUid;
  final bool canCancel;
  final DateTimeRange? range;

  /// In single-manager mode the manager records everyone's entries, so the
  /// list has to show everyone's — otherwise they'd file an entry and watch
  /// it disappear.
  final bool showEveryone;

  const _MyContributions({
    required this.group,
    required this.currentUid,
    required this.canCancel,
    required this.range,
    this.showEveryone = false,
  });

  /// A month's approved entries stop being voidable once the group's money
  /// has moved on to the builder. Not even the Creator can reach back past
  /// that line: the builder ledger already counts that money, and quietly
  /// removing a contribution behind it leaves the two sides disagreeing
  /// with no trace of why.
  ///
  /// "Moved on" is read as: any builder payment dated on or after the first
  /// of that month. A payment in a later month covers earlier collections
  /// too — money is fungible, and groups here routinely hand over a few
  /// months at once.
  ///
  /// This lives in the UI because security rules cannot ask whether such a
  /// payment exists; they read documents by path and never query. What the
  /// rules do enforce is the half that matters most — only the Creator may
  /// cancel at all.
  static bool _lockedByPayment(Contribution c, DateTime? lastPaymentDate) {
    if (lastPaymentDate == null) return false;
    return !lastPaymentDate.isBefore(DateTime(c.year, c.month));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BuilderPayment>>(
      stream: BuilderPaymentService().watch(group.id),
      builder: (context, paymentSnap) {
        final payments = paymentSnap.data ?? const <BuilderPayment>[];
        DateTime? lastPaymentDate;
        for (final p in payments) {
          if (lastPaymentDate == null || p.date.isAfter(lastPaymentDate)) {
            lastPaymentDate = p.date;
          }
        }
        return _buildList(context, lastPaymentDate);
      },
    );
  }

  Widget _buildList(BuildContext context, DateTime? lastPaymentDate) {
    return StreamBuilder<List<Contribution>>(
      stream: showEveryone
          ? ContributionService().watchGroupContributions(group.id)
          : ContributionService().watchMemberContributions(group.id, currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries =
            (snapshot.data ?? []).where((c) => isInDateRange(c.submittedAt, range)).toList();
        if (entries.isEmpty) {
          return EmptyState(icon: Icons.payments_outlined, message: S.t(context, 'no_pending_approvals'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final c = entries[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: _MethodIcon(method: c.method),
                title: Text('${c.month}/${c.year} — ${CurrencyFormatter.format(c.amount)}'),
                subtitle: showEveryone
                    ? Row(
                        children: [
                          Flexible(
                            child: MemberName(
                              uid: c.memberId,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            ' • ${S.t(context, 'method_${c.method.name}')}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      )
                    : Text(S.t(context, 'method_${c.method.name}')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusChipFor(status: c.status, rejectReason: c.rejectReason, cancelReason: c.cancelReason),
                    if (canCancel &&
                        c.status == ContributionStatus.approved &&
                        _lockedByPayment(c, lastPaymentDate))
                      IconButton(
                        icon: const Icon(Icons.lock_outline, color: AppColors.mutedText),
                        tooltip: S.t(context, 'cancel_locked'),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(S.t(context, 'cancel_locked'))),
                        ),
                      ),
                    if (canCancel &&
                        c.status == ContributionStatus.approved &&
                        !_lockedByPayment(c, lastPaymentDate))
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: S.t(context, 'cancel_entry'),
                        onPressed: () async {
                          final reason = await showTextInputDialog(context, title: S.t(context, 'cancel_reason'));
                          if (reason == null || reason.isEmpty) return;
                          try {
                            await ContributionService().cancel(
                              groupId: group.id,
                              contributionId: c.id,
                              cancelledBy: currentUid,
                              reason: reason,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ApprovalsList extends StatelessWidget {
  final LandGroup group;
  final String currentUid;
  final DateTimeRange? range;
  const _ApprovalsList({required this.group, required this.currentUid, required this.range});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contribution>>(
      stream: ContributionService().watchPendingApprovals(group.id),
      builder: (context, snapshot) {
        final entries =
            (snapshot.data ?? []).where((c) => isInDateRange(c.submittedAt, range)).toList();
        if (entries.isEmpty) {
          return EmptyState(icon: Icons.check_circle_outline, message: S.t(context, 'no_pending_approvals'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final c = entries[index];
            final isSelf = c.memberId == currentUid || c.submittedBy == currentUid;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _MethodIcon(method: c.method),
                        const SizedBox(width: 10),
                        MemberName(
                          uid: c.memberId,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${c.month}/${c.year} — ${CurrencyFormatter.format(c.amount)} (${S.t(context, 'method_${c.method.name}')})'),
                    if (c.receiptUrl != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(child: Image.network(c.receiptUrl!)),
                        ),
                        child: Image.network(c.receiptUrl!, height: 80, fit: BoxFit.cover),
                      ),
                    ],
                    if (isSelf)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'নিজের জমা দেওয়া এন্ট্রি — অন্য একজন Admin/Collector কে অনুমোদন করতে হবে',
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                final reason = await showTextInputDialog(
                                  context,
                                  title: S.t(context, 'reject_reason'),
                                );
                                if (reason == null || reason.isEmpty) return;
                                try {
                                  await ContributionService().reject(
                                    groupId: group.id,
                                    contributionId: c.id,
                                    approverId: currentUid,
                                    reason: reason,
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                  }
                                }
                              },
                              child: Text(S.t(context, 'reject')),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await ContributionService()
                                      .approve(groupId: group.id, contributionId: c.id, approverId: currentUid);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                  }
                                }
                              },
                              child: Text(S.t(context, 'approve')),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MethodIcon extends StatelessWidget {
  final PaymentMethod method;
  const _MethodIcon({required this.method});

  static const _icons = {
    PaymentMethod.bkash: Icons.phone_android,
    PaymentMethod.bank: Icons.account_balance_outlined,
    PaymentMethod.cash: Icons.payments_outlined,
    PaymentMethod.other: Icons.more_horiz,
  };

  static const _colors = {
    PaymentMethod.bkash: (Color(0xFFFCE4EC), Color(0xFFAD1457)),
    PaymentMethod.bank: (Color(0xFFE3F2FD), Color(0xFF1565C0)),
    PaymentMethod.cash: (Color(0xFFE8F5E9), Color(0xFF2E7D32)),
    PaymentMethod.other: (Color(0xFFEDE7F6), Color(0xFF4527A0)),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors[method]!;
    return CircleAvatar(
      backgroundColor: bg,
      foregroundColor: fg,
      radius: 18,
      child: Icon(_icons[method], size: 18),
    );
  }
}

class _StatusChipFor extends StatelessWidget {
  final ContributionStatus status;
  final String? rejectReason;
  final String? cancelReason;
  const _StatusChipFor({required this.status, this.rejectReason, this.cancelReason});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ContributionStatus.approved:
        return StatusChip(
          label: S.t(context, 'status_approved'),
          background: AppColors.approvedBg,
          foreground: AppColors.approvedFg,
        );
      case ContributionStatus.rejected:
        return Tooltip(
          message: rejectReason ?? '',
          child: StatusChip(
            label: S.t(context, 'status_rejected'),
            background: AppColors.rejectedBg,
            foreground: AppColors.rejectedFg,
          ),
        );
      case ContributionStatus.cancelled:
        return Tooltip(
          message: cancelReason ?? '',
          child: StatusChip(
            label: S.t(context, 'status_cancelled'),
            background: AppColors.cancelledBg,
            foreground: AppColors.cancelledFg,
          ),
        );
      case ContributionStatus.pendingConfirmation:
        return StatusChip(
          label: S.t(context, 'status_pending'),
          background: AppColors.pendingBg,
          foreground: AppColors.pendingFg,
        );
    }
  }
}

class _SubmitContributionDialog extends StatefulWidget {
  final LandGroup group;
  final String memberId;

  /// Single-manager mode: the entry can be for any member, and it's booked
  /// as approved on the spot (there's nobody else to approve it).
  final bool managesEveryone;

  const _SubmitContributionDialog({
    required this.group,
    required this.memberId,
    this.managesEveryone = false,
  });

  @override
  State<_SubmitContributionDialog> createState() => _SubmitContributionDialogState();
}

class _SubmitContributionDialogState extends State<_SubmitContributionDialog> {
  final _amountCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.bkash;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  XFile? _receiptFile;
  bool _saving = false;
  String? _error;

  late String _forMemberId = widget.memberId;
  List<GroupMember> _members = const [];

  @override
  void initState() {
    super.initState();
    _loadAmountFor(_forMemberId);
    if (widget.managesEveryone) {
      GroupService().watchMembers(widget.group.id).first.then((members) {
        if (!mounted) return;
        final active = members.where((m) => m.isActive).toList();
        setState(() {
          _members = active;
          // The dropdown asserts if its value isn't among its items, which
          // is exactly what happens if the manager's own membership has been
          // exited — fall back to whoever is first.
          if (active.isNotEmpty && !active.any((m) => m.uid == _forMemberId)) {
            _forMemberId = active.first.uid;
            _loadAmountFor(_forMemberId);
          }
        });
      });
    }
  }

  /// Pre-fills the amount with whatever this member owes each month, so the
  /// common case is one tap.
  void _loadAmountFor(String uid) {
    GroupService().getMember(widget.group.id, uid).then((m) {
      if (m != null && mounted) {
        _amountCtrl.text = m.monthlyAmount == 0 ? '' : m.monthlyAmount.toString();
      }
    });
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _receiptFile = picked);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = S.t(context, 'invalid_number'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Receipt photo is optional — upload one only if the member chose to.
      String? receiptUrl;
      if (_receiptFile != null) {
        receiptUrl = await StorageService().uploadReceipt(
          groupId: widget.group.id,
          uploaderUid: widget.memberId,
          file: _receiptFile!,
        );
      }
      await ContributionService().submit(
        groupId: widget.group.id,
        memberId: _forMemberId,
        month: _month,
        year: _year,
        amount: amount,
        method: _method,
        receiptUrl: receiptUrl,
        submittedBy: widget.memberId,
        singleManager: widget.managesEveryone,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.t(context, 'mark_paid')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.managesEveryone && _members.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _forMemberId,
                isExpanded: true,
                decoration: InputDecoration(labelText: S.t(context, 'entry_for_member')),
                items: [
                  for (final m in _members) DropdownMenuItem(value: m.uid, child: MemberName(uid: m.uid)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _forMemberId = v);
                  _loadAmountFor(v);
                },
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: InputDecoration(labelText: S.t(context, 'month')),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                        .toList(),
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: InputDecoration(labelText: S.t(context, 'year')),
                    items: List.generate(5, (i) => DateTime.now().year - 1 + i)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) => setState(() => _year = v ?? _year),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'amount'), border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: InputDecoration(labelText: S.t(context, 'payment_method')),
              items: PaymentMethod.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(S.t(context, 'method_${m.name}'))))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _receiptFile == null ? '${S.t(context, 'upload_receipt')} (ঐচ্ছিক)' : 'রিসিট নির্বাচিত হয়েছে ✓',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.t(context, 'cancel'))),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(S.t(context, 'submit')),
        ),
      ],
    );
  }
}
