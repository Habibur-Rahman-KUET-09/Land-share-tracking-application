import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/builder_payment.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/builder_payment_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';

/// FR 2.4: what an Admin actually remitted to the land's builder/developer.
class BuilderPaymentScreen extends StatelessWidget {
  final LandGroup group;
  final bool canRecord;
  const BuilderPaymentScreen({super.key, required this.group, required this.canRecord});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<BuilderPayment>>(
        stream: BuilderPaymentService().watch(group.id),
        builder: (context, snapshot) {
          final payments = snapshot.data ?? [];
          final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0x1A0F6E5C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Text(S.t(context, 'total_remitted')),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: payments.isEmpty
                    ? EmptyState(icon: Icons.account_balance_outlined, message: S.t(context, 'no_pending_approvals'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final p = payments[index];
                          final (iconBg, iconFg) = AppColors.accentFor(p.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconBg,
                                foregroundColor: iconFg,
                                child: const Icon(Icons.payments_outlined, size: 18),
                              ),
                              title: Text(CurrencyFormatter.format(p.amount)),
                              subtitle: Text(
                                '${p.date.day}-${p.date.month}-${p.date.year}'
                                '${p.referenceNumber != null ? ' • ${p.referenceNumber}' : ''}',
                              ),
                              trailing: p.receiptUrl != null
                                  ? IconButton(
                                      icon: const Icon(Icons.receipt_long_outlined),
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => Dialog(child: Image.network(p.receiptUrl!)),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
              if (canRecord)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => _RecordPaymentDialog(group: group)),
                      icon: const Icon(Icons.add),
                      label: Text(S.t(context, 'record_builder_payment')),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordPaymentDialog extends StatefulWidget {
  final LandGroup group;
  const _RecordPaymentDialog({required this.group});

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  File? _receiptFile;
  bool _saving = false;
  String? _error;

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _receiptFile = File(picked.path));
  }

  Future<void> _save() async {
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
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      String? receiptUrl;
      if (_receiptFile != null) {
        receiptUrl = await StorageService()
            .uploadReceipt(groupId: widget.group.id, uploaderUid: uid, file: _receiptFile!);
      }
      await BuilderPaymentService().record(
        groupId: widget.group.id,
        amount: amount,
        date: _date,
        referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        receiptUrl: receiptUrl,
        recordedBy: uid,
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
      title: Text(S.t(context, 'record_builder_payment')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'amount'), border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_date.day}-${_date.month}-${_date.year}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _refCtrl,
              decoration:
                  InputDecoration(labelText: S.t(context, 'reference_number'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: const Icon(Icons.upload_file),
              label: Text(_receiptFile == null ? S.t(context, 'upload_receipt') : 'রিসিট নির্বাচিত হয়েছে ✓'),
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(S.t(context, 'save')),
        ),
      ],
    );
  }
}
