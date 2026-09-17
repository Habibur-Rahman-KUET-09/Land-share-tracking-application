import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/group_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/group_type_labels.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kistify_mark.dart';
import '../group/create_group_screen.dart';
import '../group/group_detail_screen.dart';
import '../notifications/notifications_screen.dart';

/// Screen 1 (Home): FR 2.1 "একাধিক group সাপোর্ট" — every group the signed-in
/// user belongs to.
class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  static const _cardIcons = [
    Icons.holiday_village_outlined,
    Icons.groups_outlined,
    Icons.location_on_outlined,
    Icons.landscape_outlined,
    Icons.home_work_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final uid = auth.firebaseUser!.uid;
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KistifyMark(size: 26),
            const SizedBox(width: 10),
            Text(S.t(context, 'my_groups')),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: NotificationService().watchUnreadCount(uid),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return IconButton(
                tooltip: S.t(context, 'notifications'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              );
            },
          ),
          IconButton(
            tooltip: S.t(context, 'language'),
            icon: const Icon(Icons.translate),
            onPressed: () => context.read<LocaleProvider>().toggle(),
          ),
          IconButton(
            tooltip: S.t(context, 'logout'),
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppAuthProvider>().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<LandGroup>>(
        stream: groupService.watchUserGroups(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Surface a real Firestore error (most commonly permission-denied
          // because firestore.rules hasn't been deployed to the console
          // yet) instead of silently falling through to "no groups" — a
          // group that failed to load looked exactly like a group that was
          // never created.
          if (snapshot.hasError) {
            return EmptyState(icon: Icons.cloud_off, message: '${snapshot.error}');
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Column(
              children: [
                Expanded(child: EmptyState(icon: Icons.landscape_outlined, message: S.t(context, 'no_groups'))),
                const _NewGroupLink(),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final g in groups)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border, width: 0.6),
                  ),
                  child: ListTile(
                    leading: Builder(builder: (context) {
                      final (bg, fg) = AppColors.accentFor(g.id);
                      final i = g.id.hashCode.abs() % _cardIcons.length;
                      return CircleAvatar(
                        backgroundColor: bg,
                        foregroundColor: fg,
                        child: Icon(_cardIcons[i]),
                      );
                    }),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    // Built from whatever the group's type actually has —
                    // a lottery has no location, value or installment count,
                    // and would otherwise read " • ৳0 • 0 কিস্তি".
                    subtitle: Text(
                      [
                        S.t(context, g.groupType.nameKey),
                        if (g.landLocation.isNotEmpty) g.landLocation,
                        if (g.totalLandValue > 0) CurrencyFormatter.format(g.totalLandValue),
                        if (g.groupType.hasInstallmentCount && g.totalInstallments > 0)
                          '${g.totalInstallments} কিস্তি',
                      ].join(' • '),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.mutedText),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id)),
                    ),
                  ),
                ),
              const _NewGroupLink(),
            ],
          );
        },
      ),
    );
  }
}

class _NewGroupLink extends StatelessWidget {
  const _NewGroupLink();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          ),
          icon: const Icon(Icons.add, size: 18, color: AppColors.mutedText),
          label: Text(S.t(context, 'new_group'), style: const TextStyle(color: AppColors.mutedText)),
        ),
      ),
    );
  }
}
