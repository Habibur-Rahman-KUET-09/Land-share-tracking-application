import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../services/group_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../home/group_list_screen.dart';
import 'edit_plan_screen.dart';

/// Creator-only hub: edit the installment plan, or delete the group
/// entirely. Reached from GroupDetailScreen's app bar (Creator only).
class GroupManagementScreen extends StatefulWidget {
  final LandGroup group;
  const GroupManagementScreen({super.key, required this.group});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.t(context, 'delete_group'),
      message:
          '"${widget.group.name}" গ্রুপটি স্থায়ীভাবে মুছে যাবে — সব সদস্য, কিস্তির এন্ট্রি, বিল্ডার পেমেন্ট, '
          'ও অ্যাক্টিভিটি লগ সহ। এটি ফিরিয়ে আনা যাবে না।',
      isDestructive: true,
      confirmLabel: S.t(context, 'delete_group'),
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      await GroupService().deleteGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GroupListScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'group_management'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: Text(S.t(context, 'edit_plan')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditPlanScreen(group: widget.group)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              title: Text(
                S.t(context, 'delete_group'),
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('গ্রুপ ও এর সব ডেটা স্থায়ীভাবে মুছে ফেলুন'),
              trailing: _deleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _deleting ? null : _delete,
            ),
          ),
        ],
      ),
    );
  }
}
