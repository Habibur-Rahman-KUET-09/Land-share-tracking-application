import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../audit/audit_log_screen.dart';
import '../builder_payment/builder_payment_screen.dart';
import '../contribution/contributions_tab.dart';
import '../dashboard/dashboard_screen.dart';
import '../reports/reports_screen.dart';
import '../transparency/transparency_screen.dart';
import '../../widgets/kistify_app_bar.dart';
import 'group_management_screen.dart';
import 'members_tab.dart';

/// The group's hub: Dashboard, Members, Contributions, Builder Payments,
/// Reports, Transparency ledger, Audit log — one tab per FRD module.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _groupService = GroupService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AppAuthProvider>().firebaseUser!.uid;

    return StreamBuilder<LandGroup?>(
      stream: _groupService.watchGroup(widget.groupId),
      builder: (context, groupSnap) {
        // Without this, a Firestore error here (most commonly
        // permission-denied because firestore.rules hasn't been deployed to
        // the console yet) left `group` null forever — an infinite loading
        // spinner with no explanation, right after "successfully" creating
        // the group.
        if (groupSnap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${groupSnap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          );
        }
        final group = groupSnap.data;
        if (group == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return FutureBuilder<GroupMember?>(
          future: _groupService.getMember(widget.groupId, uid),
          builder: (context, memberSnap) {
            final me = memberSnap.data;
            final canManageGroup = me?.canManageGroup ?? false;
            final canApprove = me?.canApproveOrRejectContribution ?? false;
            final canCancel = me?.canCancelApprovedContribution ?? false;
            final canRecordPayment = me?.canRecordBuilderPayment ?? false;
            final canViewReports = me?.canDownloadReports ?? false;
            final canViewAudit = me?.canViewAuditLog ?? false;
            return Scaffold(
              appBar: KistifyAppBar(
                title: group.name,
                actions: [
                  if (canManageGroup)
                    IconButton(
                      tooltip: S.t(context, 'group_management'),
                      icon: const Icon(Icons.tune),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => GroupManagementScreen(group: group)),
                      ),
                    ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    Tab(text: S.t(context, 'dashboard')),
                    Tab(text: S.t(context, 'members')),
                    Tab(text: S.t(context, 'contributions')),
                    Tab(text: S.t(context, 'builder_payments')),
                    Tab(text: S.t(context, 'reports')),
                    Tab(text: S.t(context, 'transparency')),
                    Tab(text: S.t(context, 'audit_log')),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  DashboardScreen(group: group, currentUid: uid),
                  MembersTab(group: group, canManage: canManageGroup, currentUid: uid),
                  ContributionsTab(
                    group: group,
                    canApprove: canApprove,
                    canCancel: canCancel,
                    currentUid: uid,
                  ),
                  BuilderPaymentScreen(group: group, canRecord: canRecordPayment),
                  ReportsScreen(group: group, canView: canViewReports),
                  TransparencyScreen(group: group),
                  AuditLogScreen(groupId: group.id, canView: canViewAudit),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
