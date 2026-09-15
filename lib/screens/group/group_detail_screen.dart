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
import 'edit_plan_screen.dart';
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
        final group = groupSnap.data;
        if (group == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return FutureBuilder<GroupMember?>(
          future: _groupService.getMember(widget.groupId, uid),
          builder: (context, memberSnap) {
            final me = memberSnap.data;
            final isAdmin = me?.isAdmin ?? false;
            return Scaffold(
              appBar: AppBar(
                title: Text(group.name),
                actions: [
                  if (isAdmin)
                    IconButton(
                      tooltip: S.t(context, 'edit_plan'),
                      icon: const Icon(Icons.tune),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EditPlanScreen(group: group)),
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
                  MembersTab(group: group, isAdmin: isAdmin, currentUid: uid),
                  ContributionsTab(group: group, isAdmin: isAdmin, currentUid: uid),
                  BuilderPaymentScreen(group: group, isAdmin: isAdmin),
                  ReportsScreen(group: group),
                  TransparencyScreen(group: group),
                  AuditLogScreen(groupId: group.id),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
