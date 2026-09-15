import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import 'group_detail_screen.dart';

/// FR 2.1 "একটি 'Land Group' তৈরি করা" + FR 2.2 "Installment Plan Setup" —
/// combined into one form since a group can't meaningfully exist without
/// its plan.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _totalValueCtrl = TextEditingController();
  final _totalInstallmentsCtrl = TextEditingController();
  final _monthlyTotalCtrl = TextEditingController();
  int _dueDay = 5;
  ContributionType _contributionType = ContributionType.equal;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _totalValueCtrl.dispose();
    _totalInstallmentsCtrl.dispose();
    _monthlyTotalCtrl.dispose();
    super.dispose();
  }

  String? _numberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return S.t(context, 'required_field');
    if (double.tryParse(v.trim()) == null) return S.t(context, 'invalid_number');
    return null;
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      final groupId = await GroupService().createGroup(
        name: _nameCtrl.text.trim(),
        landLocation: _locationCtrl.text.trim(),
        totalLandValue: double.parse(_totalValueCtrl.text.trim()),
        totalInstallments: int.parse(_totalInstallmentsCtrl.text.trim()),
        monthlyTotalToBuilder: double.parse(_monthlyTotalCtrl.text.trim()),
        dueDayOfMonth: _dueDay,
        contributionType: _contributionType,
        creatorUid: uid,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'new_group'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'group_name'), border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration:
                  InputDecoration(labelText: S.t(context, 'land_location'), border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalValueCtrl,
              decoration:
                  InputDecoration(labelText: S.t(context, 'total_land_value'), border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: _numberValidator,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _totalInstallmentsCtrl,
              decoration: InputDecoration(
                labelText: S.t(context, 'total_installments'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _numberValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _monthlyTotalCtrl,
              decoration: InputDecoration(
                labelText: S.t(context, 'monthly_total_to_builder'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: _numberValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(S.t(context, 'due_day'))),
                DropdownButton<int>(
                  value: _dueDay,
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                      .toList(),
                  onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(S.t(context, 'contribution_type'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SegmentedButton<ContributionType>(
              segments: [
                ButtonSegment(value: ContributionType.equal, label: Text(S.t(context, 'contribution_equal'))),
                ButtonSegment(value: ContributionType.custom, label: Text(S.t(context, 'contribution_custom'))),
              ],
              selected: {_contributionType},
              onSelectionChanged: (s) => setState(() => _contributionType = s.first),
            ),
            if (_contributionType == ContributionType.custom) ...[
              const SizedBox(height: 8),
              Text(
                'প্রতিটি সদস্যের কিস্তির পরিমাণ সদস্য যোগ করার সময় আলাদাভাবে সেট করতে পারবেন।',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(S.t(context, 'create')),
            ),
          ],
        ),
      ),
    );
  }
}
