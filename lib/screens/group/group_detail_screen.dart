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
import '../lottery/lottery_screen.dart';
import '../reports/reports_screen.dart';
import '../transparency/transparency_screen.dart';
import '../../utils/group_type_labels.dart';
import '../../widgets/kistify_app_bar.dart';
import 'group_management_screen.dart';
import 'members_tab.dart';

/// The group's hub: Dashboard, Members, Contributions, the outgoing-money
/// ledger, Reports, Transparency ledger, Audit log — one tab per FRD module,
/// minus whichever the current member has no access to at all (Reports, Audit
/// Log — both Admin/Creator-only) and whichever the group's type doesn't have
/// (a lottery pays its winner directly, so it gets a Lottery tab in place of
/// the builder-payment ledger; a savings group calls that ledger "bank
/// deposits").
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupService = GroupService();

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
            return _GroupTabs(group: group, me: me, currentUid: uid);
          },
        );
      },
    );
  }
}

/// Owns the TabController, sized to exactly the tabs this member can see —
/// built fresh (via the ValueKey below) whenever the member's permissions
/// change, so the controller's length always matches the visible tab count.
class _GroupTabs extends StatefulWidget {
  final LandGroup group;
  final GroupMember? me;
  final String currentUid;

  _GroupTabs({required this.group, required this.me, required this.currentUid})
      : super(key: ValueKey('${group.groupType.name}-${me?.canDownloadReports}-${me?.canViewAuditLog}'));

  @override
  State<_GroupTabs> createState() => _GroupTabsState();
}

class _GroupTabsState extends State<_GroupTabs> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get _canManageGroup => widget.me?.canManageGroup ?? false;
  bool get _canApprove => widget.me?.canApproveOrRejectContribution ?? false;
  bool get _canCancel => widget.me?.canCancelApprovedContribution ?? false;
  bool get _canRecordPayment => widget.me?.canRecordBuilderPayment ?? false;
  bool get _canViewReports => widget.me?.canDownloadReports ?? false;
  bool get _canViewAudit => widget.me?.canViewAuditLog ?? false;
  bool get _canEditNames => widget.me?.canEditMemberNames ?? false;
  bool get _canRunLottery => widget.me?.canRunLottery ?? false;

  String? get _outgoingTabKey => widget.group.groupType.outgoingTabKey;
  bool get _hasLottery => widget.group.groupType.hasLottery;

  @override
  void initState() {
    super.initState();
    // Dashboard, Members, Contributions, Transparency are always there; the
    // rest depend on the group's type and this member's permissions.
    final tabCount = 4 +
        (_outgoingTabKey != null ? 1 : 0) +
        (_hasLottery ? 1 : 0) +
        (_canViewReports ? 1 : 0) +
        (_canViewAudit ? 1 : 0);
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final uid = widget.currentUid;

    final tabs = <Tab>[
      Tab(text: S.t(context, 'dashboard')),
      Tab(text: S.t(context, 'members')),
      Tab(text: S.t(context, 'contributions')),
      if (_outgoingTabKey != null) Tab(text: S.t(context, _outgoingTabKey!)),
      if (_hasLottery) Tab(text: S.t(context, 'lottery')),
      if (_canViewReports) Tab(text: S.t(context, 'reports')),
      Tab(text: S.t(context, 'transparency')),
      if (_canViewAudit) Tab(text: S.t(context, 'audit_log')),
    ];

    final tabViews = <Widget>[
      DashboardScreen(group: group, currentUid: uid),
      MembersTab(group: group, canManage: _canManageGroup, canEditNames: _canEditNames, currentUid: uid),
      ContributionsTab(group: group, canApprove: _canApprove, canCancel: _canCancel, currentUid: uid),
      if (_outgoingTabKey != null) BuilderPaymentScreen(group: group, canRecord: _canRecordPayment),
      if (_hasLottery) LotteryScreen(group: group, canDraw: _canRunLottery, currentUid: uid),
      if (_canViewReports) ReportsScreen(group: group, canView: true),
      TransparencyScreen(group: group),
      if (_canViewAudit) AuditLogScreen(groupId: group.id, canView: true),
    ];

    return Scaffold(
      appBar: KistifyAppBar(
        title: group.name,
        actions: [
          if (_canManageGroup)
            IconButton(
              tooltip: S.t(context, 'group_management'),
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GroupManagementScreen(group: group)),
              ),
            ),
        ],
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: tabs),
      ),
      body: TabBarView(controller: _tabController, children: tabViews),
    );
  }
}
