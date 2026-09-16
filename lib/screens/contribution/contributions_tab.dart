import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_user.dart';
import '../../models/contribution.dart';
import '../../models/land_group.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../services/storage_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (widget.canApprove)
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
          Expanded(
            child: _showApprovals
                ? _ApprovalsList(group: widget.group, currentUid: widget.currentUid)
                : _MyContributions(group: widget.group, currentUid: widget.currentUid, canCancel: widget.canCancel),
          ),
        ],
      ),
      floatingActionButton: _showApprovals
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _SubmitContributionDialog(group: widget.group, memberId: widget.currentUid),
              ),
              icon: const Icon(Icons.add),
              label: Text(S.t(context, 'mark_paid')),
            ),
    );
  }
}

class _MyContributions extends StatelessWidget {
  final LandGroup group;
  final String currentUid;
  final bool canCancel;
  const _MyContributions({required this.group, required this.currentUid, required this.canCancel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contribution>>(
      stream: ContributionService().watchMemberContributions(group.id, currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data ?? [];
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
                title: Text('${c.month}/${c.year} — ${CurrencyFormatter.format(c.amount)}'),
                subtitle: Text(S.t(context, 'method_${c.method.name}')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusChipFor(status: c.status, rejectReason: c.rejectReason, cancelReason: c.cancelReason),
                    if (canCancel && c.status == ContributionStatus.approved)
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
  const _ApprovalsList({required this.group, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contribution>>(
      stream: ContributionService().watchPendingApprovals(group.id),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
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
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('users').doc(c.memberId).get(),
                      builder: (context, userSnap) {
                        final name = userSnap.data?.exists == true
                            ? AppUser.fromMap(c.memberId, userSnap.data!.data()!).name
                            : c.memberId;
                        return Text(name, style: const TextStyle(fontWeight: FontWeight.bold));
                      },
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

class _StatusChipFor extends StatelessWidget {
  final ContributionStatus status;
  final String? rejectReason;
  final String? cancelReason;
  const _StatusChipFor({required this.status, this.rejectReason, this.cancelReason});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ContributionStatus.approved:
        return StatusChip(label: S.t(context, 'status_approved'), color: Colors.green);
      case ContributionStatus.rejected:
        return Tooltip(
          message: rejectReason ?? '',
          child: StatusChip(label: S.t(context, 'status_rejected'), color: Colors.red),
        );
      case ContributionStatus.cancelled:
        return Tooltip(
          message: cancelReason ?? '',
          child: StatusChip(label: S.t(context, 'status_cancelled'), color: Colors.grey),
        );
      case ContributionStatus.pendingConfirmation:
        return StatusChip(label: S.t(context, 'status_pending'), color: Colors.orange);
    }
  }
}

class _SubmitContributionDialog extends StatefulWidget {
  final LandGroup group;
  final String memberId;
  const _SubmitContributionDialog({required this.group, required this.memberId});

  @override
  State<_SubmitContributionDialog> createState() => _SubmitContributionDialogState();
}

class _SubmitContributionDialogState extends State<_SubmitContributionDialog> {
  final _amountCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.bkash;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  File? _receiptFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    GroupService().getMember(widget.group.id, widget.memberId).then((m) {
      if (m != null && mounted) {
        _amountCtrl.text = m.monthlyAmount == 0 ? '' : m.monthlyAmount.toString();
      }
    });
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _receiptFile = File(picked.path));
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
        memberId: widget.memberId,
        month: _month,
        year: _year,
        amount: amount,
        method: _method,
        receiptUrl: receiptUrl,
        submittedBy: widget.memberId,
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
