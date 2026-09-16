import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../models/plan_history_entry.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/kistify_app_bar.dart';

/// FR Finalized Decision 4: "Installment Plan ফিক্সড না — ভবিষ্যতে
/// পরিবর্তনযোগ্য, তবে history log থাকবে" — this screen both edits the plan
/// and shows that history.
class EditPlanScreen extends StatefulWidget {
  final LandGroup group;
  const EditPlanScreen({super.key, required this.group});

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  late final TextEditingController _totalInstallmentsCtrl;
  late final TextEditingController _monthlyTotalCtrl;
  late int _dueDay;
  late ContributionType _contributionType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _totalInstallmentsCtrl = TextEditingController(text: widget.group.totalInstallments.toString());
    _monthlyTotalCtrl = TextEditingController(text: widget.group.monthlyTotalToBuilder.toString());
    _dueDay = widget.group.dueDayOfMonth;
    _contributionType = widget.group.contributionType;
  }

  @override
  void dispose() {
    _totalInstallmentsCtrl.dispose();
    _monthlyTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      await GroupService().editPlan(
        groupId: widget.group.id,
        totalInstallments: int.tryParse(_totalInstallmentsCtrl.text.trim()) ?? widget.group.totalInstallments,
        monthlyTotalToBuilder:
            double.tryParse(_monthlyTotalCtrl.text.trim()) ?? widget.group.monthlyTotalToBuilder,
        dueDayOfMonth: _dueDay,
        contributionType: _contributionType,
        editedBy: uid,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'edit_plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _totalInstallmentsCtrl,
            decoration:
                InputDecoration(labelText: S.t(context, 'total_installments'), border: const OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(S.t(context, 'due_day'))),
              DropdownButton<int>(
                value: _dueDay,
                items:
                    List.generate(28, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ContributionType>(
            segments: [
              ButtonSegment(value: ContributionType.equal, label: Text(S.t(context, 'contribution_equal'))),
              ButtonSegment(value: ContributionType.custom, label: Text(S.t(context, 'contribution_custom'))),
            ],
            selected: {_contributionType},
            onSelectionChanged: (s) => setState(() => _contributionType = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(S.t(context, 'save')),
          ),
          const SizedBox(height: 24),
          const Divider(),
          Text(S.t(context, 'plan_history'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<PlanHistoryEntry>>(
            stream: GroupService().watchPlanHistory(widget.group.id),
            builder: (context, snapshot) {
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('কোনো পরিবর্তনের ইতিহাস নেই।', style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: history
                    .map(
                      (h) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            '${h.totalInstallments} কিস্তি, ${CurrencyFormatter.format(h.monthlyTotalToBuilder)}/মাস',
                          ),
                          subtitle: Text('${h.editedAt.day}-${h.editedAt.month}-${h.editedAt.year}'),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
