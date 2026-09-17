import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/group_type_labels.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/kistify_app_bar.dart';
import '../home/group_list_screen.dart';
import 'edit_plan_screen.dart';

/// Creator-only hub: edit the group name/plan, or delete the group
/// entirely. Reached from GroupDetailScreen's app bar (Creator only).
class GroupManagementScreen extends StatefulWidget {
  final LandGroup group;
  const GroupManagementScreen({super.key, required this.group});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  bool _deleting = false;
  bool _renaming = false;
  late bool _singleManager = widget.group.singleManager;
  bool _savingMode = false;

  Future<void> _setSingleManager(bool value) async {
    setState(() {
      _singleManager = value;
      _savingMode = true;
    });
    try {
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      await GroupService().setSingleManager(
        groupId: widget.group.id,
        singleManager: value,
        editedBy: uid,
      );
    } catch (e) {
      // Put the switch back where it was — leaving it flipped would claim a
      // change that Firestore rejected.
      if (mounted) {
        setState(() => _singleManager = !value);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: widget.group.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t(context, 'group_name')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: S.t(context, 'group_name'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.t(context, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: Text(S.t(context, 'save')),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == widget.group.name) return;
    if (!mounted) return;
    setState(() => _renaming = true);
    try {
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      await GroupService().renameGroup(groupId: widget.group.id, name: newName, editedBy: uid);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

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
      appBar: KistifyAppBar(title: S.t(context, 'group_management')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.drive_file_rename_outline),
              ),
              title: Text(S.t(context, 'group_name')),
              subtitle: Text(widget.group.name),
              trailing: _renaming
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _renaming ? null : _rename,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.tune),
              ),
              title: Text(S.t(context, 'edit_plan')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditPlanScreen(group: widget.group)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(widget.group.groupType.icon),
              ),
              title: Text(S.t(context, 'group_type')),
              // Read-only: switching an existing group's type would leave its
              // recorded entries meaning something they never meant.
              subtitle: Text(S.t(context, widget.group.groupType.nameKey)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const CircleAvatar(
                backgroundColor: Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.person_pin_outlined),
              ),
              value: _singleManager,
              onChanged: _savingMode ? null : _setSingleManager,
              title: Text(S.t(context, 'single_manager')),
              subtitle: Text(
                S.t(context, 'single_manager_desc'),
                style: const TextStyle(fontSize: 12.5),
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
