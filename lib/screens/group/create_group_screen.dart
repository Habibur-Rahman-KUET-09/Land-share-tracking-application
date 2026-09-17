import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/group_type_labels.dart';
import '../../widgets/kistify_app_bar.dart';
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
  GroupType _groupType = GroupType.installment;
  bool _singleManager = false;
  ContributionType _contributionType = ContributionType.equal;
  bool _saving = false;
  String? _error;

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

  /// Savings groups treat the target as optional, so an empty box is fine
  /// there — everywhere else the field is required.
  String? _optionalNumberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (double.tryParse(v.trim()) == null) return S.t(context, 'invalid_number');
    return null;
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      final groupId = await GroupService().createGroup(
        name: _nameCtrl.text.trim(),
        groupType: _groupType,
        landLocation: _groupType.hasLocation ? _locationCtrl.text.trim() : '',
        totalLandValue: double.tryParse(_totalValueCtrl.text.trim()) ?? 0,
        // A lottery runs one round per member, so its length follows the
        // membership rather than a number typed in up front.
        totalInstallments: _groupType.hasInstallmentCount ? int.parse(_totalInstallmentsCtrl.text.trim()) : 0,
        monthlyTotalToBuilder: double.parse(_monthlyTotalCtrl.text.trim()),
        dueDayOfMonth: _dueDay,
        singleManager: _singleManager,
        contributionType: _contributionType,
        creatorUid: uid,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      );
    } catch (e) {
      // Without this, a Firestore error (most commonly permission-denied
      // because firestore.rules hasn't been deployed to the console yet)
      // silently did nothing: no navigation, no message — it just looked
      // like the group vanished.
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'new_group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(S.t(context, 'group_type'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final type in GroupType.values)
              _GroupTypeCard(
                type: type,
                selected: _groupType == type,
                onTap: () => setState(() => _groupType = type),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'group_name'), border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
            ),
            if (_groupType.hasLocation) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration:
                    InputDecoration(labelText: S.t(context, 'land_location'), border: const OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
              ),
            ],
            if (_groupType.totalValueKey != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalValueCtrl,
                decoration: InputDecoration(
                  labelText: S.t(context, _groupType.totalValueKey!),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                validator: _groupType == GroupType.savings ? _optionalNumberValidator : _numberValidator,
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            if (_groupType.hasInstallmentCount) ...[
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
            ],
            TextFormField(
              controller: _monthlyTotalCtrl,
              decoration: InputDecoration(
                labelText: S.t(context, _groupType.monthlyTotalKey),
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
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _singleManager,
              onChanged: (v) => setState(() => _singleManager = v),
              title: Text(S.t(context, 'single_manager')),
              subtitle: Text(
                S.t(context, 'single_manager_desc'),
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

class _GroupTypeCard extends StatelessWidget {
  final GroupType type;
  final bool selected;
  final VoidCallback onTap;
  const _GroupTypeCard({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppColors.accentFor(type.name);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.6 : 0.6,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          foregroundColor: fg,
          child: Icon(type.icon, size: 20),
        ),
        title: Text(
          S.t(context, type.nameKey),
          style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500),
        ),
        subtitle: Text(
          S.t(context, type.descriptionKey),
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
        onTap: onTap,
      ),
    );
  }
}
