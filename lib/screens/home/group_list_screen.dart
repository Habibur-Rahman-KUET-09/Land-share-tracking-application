import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/group_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import '../group/create_group_screen.dart';
import '../group/group_detail_screen.dart';

/// Screen 1 (Home): FR 2.1 "একাধিক group সাপোর্ট" — every group the signed-in
/// user belongs to (as Admin or Member).
class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final uid = auth.firebaseUser!.uid;
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t(context, 'my_groups')),
        actions: [
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
            return EmptyState(icon: Icons.landscape_outlined, message: S.t(context, 'no_groups'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${g.landLocation} • ${CurrencyFormatter.format(g.totalLandValue)} • '
                    '${g.totalInstallments} কিস্তি',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(S.t(context, 'new_group')),
      ),
    );
  }
}
