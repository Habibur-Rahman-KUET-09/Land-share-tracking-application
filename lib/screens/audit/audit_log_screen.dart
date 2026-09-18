import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/audit_log_entry.dart';
import '../../services/audit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_range_filter_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/member_name.dart';

/// FR 7 "Audit Trail/Activity Log" — Admin/Creator only, append-only.
class AuditLogScreen extends StatefulWidget {
  final String groupId;
  final bool canView;
  const AuditLogScreen({
    super.key,
    required this.groupId,
    required this.canView,
  });

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  DateTimeRange? _range;

  static const _actionLabelsBn = {
    'create_group': 'গ্রুপ তৈরি',
    'rename_group': 'গ্রুপের নাম পরিবর্তন',
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
    'import_contributions': 'Excel থেকে পুরোনো হিসাব আমদানি',
    'lottery_draw': 'লটারি ড্র',
  };

  static const _actionIcons = {
    'create_group': Icons.add_circle_outline,
    'rename_group': Icons.drive_file_rename_outline,
    'edit_plan': Icons.tune,
    'add_member': Icons.person_add_alt_outlined,
    'update_role': Icons.badge_outlined,
    'update_member_amount': Icons.edit_outlined,
    'exit_member': Icons.person_remove_outlined,
    'submit_contribution': Icons.upload_outlined,
    'approve_contribution': Icons.check_circle_outline,
    'reject_contribution': Icons.cancel_outlined,
    'cancel_contribution': Icons.undo_outlined,
    'record_builder_payment': Icons.account_balance_outlined,
    'import_contributions': Icons.upload_file_outlined,
    'lottery_draw': Icons.casino_outlined,
  };

  static const _actionColors = {
    'create_group': (Color(0xFFE0F2F1), Color(0xFF00695C)),
    'rename_group': (Color(0xFFEDE7F6), Color(0xFF4527A0)),
    'edit_plan': (Color(0xFFEDE7F6), Color(0xFF4527A0)),
    'add_member': (Color(0xFFE3F2FD), Color(0xFF1565C0)),
    'update_role': (Color(0xFFE3F2FD), Color(0xFF1565C0)),
    'update_member_amount': (Color(0xFFFFF3E0), Color(0xFF8A5300)),
    'exit_member': (Color(0xFFFCEBEB), Color(0xFF791F1F)),
    'submit_contribution': (Color(0xFFFFF3E0), Color(0xFF8A5300)),
    'approve_contribution': (Color(0xFFE3F4EC), Color(0xFF1B6B44)),
    'reject_contribution': (Color(0xFFFCEBEB), Color(0xFF791F1F)),
    'cancel_contribution': (Color(0xFFEDEDED), Color(0xFF5A5A5A)),
    'record_builder_payment': (Color(0xFFE0F2F1), Color(0xFF00695C)),
    'import_contributions': (Color(0xFFEDE7F6), Color(0xFF4527A0)),
    'lottery_draw': (Color(0xFFFFF3E0), Color(0xFF8A5300)),
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.canView) {
      return EmptyState(
        icon: Icons.lock_outline,
        message: S.t(context, 'no_permission'),
      );
    }
    return StreamBuilder<List<AuditLogEntry>>(
      stream: AuditService().watch(widget.groupId),
      builder: (context, snapshot) {
        final entries = (snapshot.data ?? [])
            .where((e) => isInDateRange(e.timestamp, _range))
            .toList();
        return Column(
          children: [
            DateRangeFilterBar(
              range: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            Expanded(
              child: entries.isEmpty
                  ? EmptyState(
                      icon: Icons.history,
                      message: S.t(context, 'no_pending_approvals'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final e = entries[index];
                        final (iconBg, iconFg) =
                            _actionColors[e.action] ??
                            (AppColors.dueBg, AppColors.dueFg);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: iconBg,
                                  foregroundColor: iconFg,
                                  child: Icon(
                                    _actionIcons[e.action] ?? Icons.history,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _actionLabelsBn[e.action] ??
                                                  e.action,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.heading,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: Text(
                                              '${e.timestamp.day}-${e.timestamp.month}-${e.timestamp.year}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF999999),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          MemberName(
                                            uid: e.actorId,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.bodyText,
                                            ),
                                          ),
                                          const Text(
                                            ' — ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.bodyText,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              e.details,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.bodyText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
