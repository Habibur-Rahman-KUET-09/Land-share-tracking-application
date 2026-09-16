import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_user.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_chip.dart';

/// FR 2.1 member/role management. "Invite" is search-by-phone/email against
/// already-registered users (see [_AddMemberDialog._search]) rather than a
/// deferred invite-link system — simpler, and the FRD's "Invite link /
/// Phone number দিয়ে" bullet is satisfied by the phone-number path; a
/// person who hasn't signed up yet is asked to register first, then can be
/// added.
class MembersTab extends StatelessWidget {
  final LandGroup group;
  final bool canManage;
  final bool canEditNames;
  final String currentUid;
  const MembersTab({
    super.key,
    required this.group,
    required this.canManage,
    required this.canEditNames,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();
    return Scaffold(
      body: StreamBuilder<List<GroupMember>>(
        stream: groupService.watchMembers(group.id),
        builder: (context, snapshot) {
          final members = snapshot.data ?? [];
          final active = members.where((m) => m.isActive).toList();
          final exited = members.where((m) => !m.isActive).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...active.map((m) => _MemberTile(
                    group: group,
                    member: m,
                    canManage: canManage,
                    canEditNames: canEditNames,
                    currentUid: currentUid,
                  )),
              if (exited.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('বের হয়ে যাওয়া সদস্য', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ...exited.map((m) => _MemberTile(
                      group: group,
                      member: m,
                      canManage: canManage,
                      canEditNames: canEditNames,
                      currentUid: currentUid,
                    )),
              ],
              if (canManage)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _AddMemberDialog(group: group, invitedBy: currentUid),
                      ),
                      icon: const Icon(Icons.add, size: 18, color: AppColors.mutedText),
                      label: Text(S.t(context, 'add_member'), style: const TextStyle(color: AppColors.mutedText)),
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

(Color, Color) _roleColors(GroupRole role) {
  switch (role) {
    case GroupRole.creator:
      return (AppColors.roleCreatorBg, AppColors.roleCreatorFg);
    case GroupRole.admin:
      return (AppColors.roleAdminBg, AppColors.roleAdminFg);
    case GroupRole.collector:
      return (AppColors.roleCollectorBg, AppColors.roleCollectorFg);
    case GroupRole.member:
      return (AppColors.roleMemberBg, AppColors.roleMemberFg);
  }
}

String _roleKey(GroupRole role) {
  switch (role) {
    case GroupRole.creator:
      return 'role_creator';
    case GroupRole.admin:
      return 'role_admin';
    case GroupRole.collector:
      return 'role_collector';
    case GroupRole.member:
      return 'role_member';
  }
}

class _MemberTile extends StatelessWidget {
  final LandGroup group;
  final GroupMember member;
  final bool canManage;
  final bool canEditNames;
  final String currentUid;
  const _MemberTile({
    required this.group,
    required this.member,
    required this.canManage,
    required this.canEditNames,
    required this.currentUid,
  });

  Future<void> _renameMember(BuildContext context, String currentName) async {
    final newName = await _promptText(context, label: S.t(context, 'name'), initial: currentName);
    if (newName == null || newName.isEmpty || newName == currentName) return;
    try {
      await AuthService().updateMemberNameAsManager(targetUid: member.uid, name: newName, viaGroupId: group.id);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _updateMemberEmail(BuildContext context, String currentEmail) async {
    final newEmail = await _promptText(
      context,
      label: S.t(context, 'email'),
      initial: currentEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (newEmail == null || newEmail.isEmpty || newEmail == currentEmail) return;
    try {
      await AuthService().updateMemberEmailAsManager(targetUid: member.uid, email: newEmail, viaGroupId: group.id);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String label,
    required String initial,
    TextInputType? keyboardType,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(member.uid).get(),
      builder: (context, snap) {
        final profile = snap.data?.exists == true ? AppUser.fromMap(member.uid, snap.data!.data()!) : null;
        final name = profile?.name ?? member.uid;
        final (roleBg, roleFg) = _roleColors(member.role);
        final (avatarBg, avatarFg) = AppColors.accentFor(member.uid);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border, width: 0.6),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: avatarBg,
              foregroundColor: avatarFg,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),
            title: Text(name),
            subtitle: Text(
              '${CurrencyFormatter.format(member.monthlyAmount)}/মাস'
              '${member.uid == currentUid ? ' • আপনি' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusChip(label: S.t(context, _roleKey(member.role)), background: roleBg, foreground: roleFg),
                // canManage's role/amount/exit items are never shown for the
                // creator's own row — group deletion (GroupManagementScreen)
                // is the only way to undo the creator. canEditNames's
                // rename/email items have no such exclusion.
                if (member.isActive && ((canManage && !member.isCreator) || canEditNames))
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      final groupService = GroupService();
                      if (v == 'rename') {
                        await _renameMember(context, name);
                      } else if (v == 'update_email') {
                        await _updateMemberEmail(context, profile?.email ?? '');
                      } else if (v.startsWith('role_')) {
                        final role = GroupRole.values.firstWhere((r) => 'role_${r.name}' == v);
                        try {
                          await groupService.updateMemberRole(
                            groupId: group.id,
                            uid: member.uid,
                            role: role,
                            actorId: currentUid,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      } else if (v == 'set_amount' && group.contributionType == ContributionType.custom) {
                        final amount = await _promptAmount(context, member.monthlyAmount);
                        if (amount != null) {
                          await groupService.updateMemberAmount(
                            groupId: group.id,
                            uid: member.uid,
                            monthlyAmount: amount,
                            actorId: currentUid,
                          );
                        }
                      } else if (v == 'exit') {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: S.t(context, 'exit_group'),
                          message: '"$name" কে গ্রুপ থেকে বের করে দেওয়া হবে। তার আগের হিসাব ঠিক থাকবে।',
                          isDestructive: true,
                          confirmLabel: S.t(context, 'exit_group'),
                        );
                        if (confirmed) {
                          await groupService.exitMember(groupId: group.id, uid: member.uid, actorId: currentUid);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (canEditNames) ...[
                        PopupMenuItem(value: 'rename', child: Text(S.t(context, 'name'))),
                        PopupMenuItem(value: 'update_email', child: Text(S.t(context, 'email'))),
                      ],
                      if (canManage && !member.isCreator) ...[
                        for (final role in [GroupRole.admin, GroupRole.collector, GroupRole.member])
                          if (role != member.role)
                            PopupMenuItem(
                              value: 'role_${role.name}',
                              child: Text('${S.t(context, _roleKey(role))} করুন'),
                            ),
                        if (group.contributionType == ContributionType.custom)
                          PopupMenuItem(value: 'set_amount', child: Text(S.t(context, 'monthly_amount'))),
                        PopupMenuItem(value: 'exit', child: Text(S.t(context, 'exit_group'))),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<double?> _promptAmount(BuildContext context, double initial) async {
    final ctrl = TextEditingController(text: initial == 0 ? '' : initial.toString());
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t(context, 'monthly_amount')),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.t(context, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(ctrl.text.trim())),
            child: Text(S.t(context, 'save')),
          ),
        ],
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final LandGroup group;
  final String invitedBy;
  const _AddMemberDialog({required this.group, required this.invitedBy});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _queryCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  GroupRole _role = GroupRole.member;
  bool _searching = false;
  String? _error;
  AppUser? _found;

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    final db = FirebaseFirestore.instance;
    final field = query.contains('@') ? 'email' : 'phone';
    final snap = await db.collection('users').where(field, isEqualTo: query).limit(1).get();
    if (snap.docs.isEmpty) {
      setState(() {
        _error = 'এই ইউজার এখনো রেজিস্টার করেননি — তাকে আগে অ্যাপে সাইন আপ করতে বলুন';
        _searching = false;
      });
      return;
    }
    setState(() {
      _found = AppUser.fromMap(snap.docs.first.id, snap.docs.first.data());
      _searching = false;
    });
  }

  Future<void> _add() async {
    if (_found == null) return;
    await GroupService().addMember(
      groupId: widget.group.id,
      uid: _found!.uid,
      role: _role,
      customMonthlyAmount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
      invitedBy: widget.invitedBy,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.t(context, 'add_member')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                labelText: S.t(context, 'invite_by_phone_email'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (_searching) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
              ),
            if (_found != null) ...[
              const SizedBox(height: 12),
              Text('পাওয়া গেছে: ${_found!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SegmentedButton<GroupRole>(
                segments: [
                  ButtonSegment(value: GroupRole.member, label: Text(S.t(context, 'role_member'))),
                  ButtonSegment(value: GroupRole.admin, label: Text(S.t(context, 'role_admin'))),
                  ButtonSegment(value: GroupRole.collector, label: Text(S.t(context, 'role_collector'))),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              if (widget.group.contributionType == ContributionType.custom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  decoration:
                      InputDecoration(labelText: S.t(context, 'monthly_amount'), border: const OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.t(context, 'cancel'))),
        FilledButton(onPressed: _found == null ? null : _add, child: Text(S.t(context, 'add_member'))),
      ],
    );
  }
}
