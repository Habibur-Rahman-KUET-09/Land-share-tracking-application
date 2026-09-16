import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/audit_log_entry.dart';
import '../../services/audit_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/member_name.dart';

/// FR 7 "Audit Trail/Activity Log" — Admin/Creator only, append-only.
class AuditLogScreen extends StatelessWidget {
  final String groupId;
  final bool canView;
  const AuditLogScreen({super.key, required this.groupId, required this.canView});

  static const _actionLabelsBn = {
    'create_group': 'গ্রুপ তৈরি',
    'edit_plan': 'পরিকল্পনা সম্পাদনা',
    'add_member': 'সদস্য যোগ',
    'update_role': 'ভূমিকা পরিবর্তন',
    'update_member_amount': 'মাসিক পরিমাণ পরিবর্তন',
    'exit_member': 'সদস্য বের হয়েছে',
    'submit_contribution': 'কিস্তি এন্ট্রি জমা',
    'approve_contribution': 'কিস্তি অনুমোদন',
    'reject_contribution': 'কিস্তি প্রত্যাখ্যান',
    'cancel_contribution': 'কিস্তি বাতিল',
    'record_builder_payment': 'বিল্ডারকে জমার এন্ট্রি',
  };

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return EmptyState(icon: Icons.lock_outline, message: S.t(context, 'no_permission'));
    }
    return StreamBuilder<List<AuditLogEntry>>(
      stream: AuditService().watch(groupId),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return EmptyState(icon: Icons.history, message: S.t(context, 'no_pending_approvals'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 20),
                title: Text(_actionLabelsBn[e.action] ?? e.action),
                subtitle: Row(
                  children: [
                    MemberName(uid: e.actorId, style: const TextStyle(fontSize: 12)),
                    const Text(' — ', style: TextStyle(fontSize: 12)),
                    Expanded(child: Text(e.details, style: const TextStyle(fontSize: 12))),
                  ],
                ),
                trailing: Text(
                  '${e.timestamp.day}-${e.timestamp.month}-${e.timestamp.year}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
